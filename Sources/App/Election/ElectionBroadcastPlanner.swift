import Foundation

/// Decides when the poller pushes the Live Activity state to APNs, with which priority, and
/// builds the payload. No Vapor here, so the throttling rules are unit tested.
///
/// Priority 10 pushes spend the activity's update budget, so they're kept for what people
/// care about: the first state, a new leader, every 10% counted and the final result.
/// Everything else goes out at priority 5 and no more often than `minInterval`.
struct ElectionBroadcastPlanner {

    enum Event: String, Encodable {
        case update
        case end
    }

    struct Decision: Equatable {
        let event: Event
        let priority: Int
        /// For the logs.
        let reason: String
    }

    struct Sent: Equatable {
        let state: ElectionLiveContentState
        let at: Date
    }

    /// Matches `ElectionLiveActivityManager.staleInterval` in the app: without a new push
    /// for this long, the widget shows the update as late.
    static let staleInterval: TimeInterval = 15 * 60
    /// iOS keeps an ended activity on the Lock Screen for at most 4 hours anyway.
    static let dismissalInterval: TimeInterval = 4 * 60 * 60
    static let milestoneStep: Double = 10

    let minInterval: TimeInterval

    /// Returns nil when nothing should be sent now.
    func decide(_ state: ElectionLiveContentState, lastSent: Sent?, now: Date) -> Decision? {
        guard let lastSent else {
            // A result that was already final when we started watching (the simulation
            // between test windows, or a server restart after the count) isn't news:
            // announcing it would end activities with an old result.
            return state.isFinal ? nil : Decision(event: .update, priority: 10, reason: "first push")
        }
        guard state != lastSent.state else { return nil }

        if state.isFinal {
            return Decision(event: .end, priority: 10, reason: "final result")
        }
        // Only happens when a replay restarts: activities started since then need to hear
        // about the new count right away.
        if lastSent.state.isFinal {
            return Decision(event: .update, priority: 10, reason: "count restarted")
        }
        guard now.timeIntervalSince(lastSent.at) >= minInterval else { return nil }

        if state.candidates.first?.number != lastSent.state.candidates.first?.number {
            return Decision(event: .update, priority: 10, reason: "new leader")
        }
        if Self.milestone(of: state) != Self.milestone(of: lastSent.state) {
            return Decision(event: .update, priority: 10, reason: "\(Int(Self.milestone(of: state)))% counted")
        }
        return Decision(event: .update, priority: 5, reason: "progress")
    }

    static func milestone(of state: ElectionLiveContentState) -> Double {
        (state.sectionsCountedPercent / milestoneStep).rounded(.down) * milestoneStep
    }

    // MARK: - Payload

    static func payload(for state: ElectionLiveContentState, decision: Decision, now: Date) -> Payload {
        let timestamp = Int(now.timeIntervalSince1970)
        switch decision.event {
        case .update:
            return Payload(aps: .init(
                timestamp: timestamp,
                event: .update,
                contentState: state,
                staleDate: timestamp + Int(staleInterval),
                dismissalDate: nil,
                alert: nil
            ))
        case .end:
            return Payload(aps: .init(
                timestamp: timestamp,
                event: .end,
                contentState: state,
                staleDate: nil,
                dismissalDate: timestamp + Int(dismissalInterval),
                alert: finalAlert(for: state)
            ))
        }
    }

    /// `apns-expiration`: how long APNs keeps the message for devices that are offline.
    /// An update is useless once the next one is due; the result is worth delivering late.
    static func expiration(for decision: Decision, now: Date) -> Int {
        let lifetime = decision.event == .end ? dismissalInterval : staleInterval
        return Int(now.timeIntervalSince1970 + lifetime)
    }

    /// Lights up the Lock Screen when the result is known.
    static func finalAlert(for state: ElectionLiveContentState) -> Payload.Alert {
        let title = "Apuração encerrada"
        if let winner = state.candidates.first(where: { $0.status == .elected }) {
            return .init(title: title, body: "\(winner.name) (\(winner.party)) vence com \(formatted(winner.percent))% dos votos válidos.")
        }
        let finalists = state.candidates.filter { $0.status == .runoff }
        if finalists.count == 2 {
            return .init(title: title, body: "\(finalists[0].name) e \(finalists[1].name) vão para o 2º turno.")
        }
        return .init(title: title, body: "Veja o resultado da eleição para Presidente.")
    }

    private static func formatted(_ percent: Double) -> String {
        String(format: "%.2f", percent).replacingOccurrences(of: ".", with: ",")
    }

    struct Payload: Encodable, Equatable {
        let aps: APS

        struct APS: Encodable, Equatable {
            let timestamp: Int
            let event: Event
            let contentState: ElectionLiveContentState
            let staleDate: Int?
            let dismissalDate: Int?
            let alert: Alert?

            enum CodingKeys: String, CodingKey {
                case timestamp
                case event
                case contentState = "content-state"
                case staleDate = "stale-date"
                case dismissalDate = "dismissal-date"
                case alert
            }
        }

        struct Alert: Encodable, Equatable {
            let title: String
            let body: String
        }
    }
}
