@testable import App
import Testing
import VaporTesting
import Foundation

struct ElectionBroadcastPlannerTests {

    private let planner = ElectionBroadcastPlanner(minInterval: 30)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func state(at progress: Double) throws -> ElectionLiveContentState {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        return ElectionLiveContentState(snapshot: ElectionReplay(final: final).snapshot(at: progress), candidateColors: [:])
    }

    private func sent(_ state: ElectionLiveContentState, secondsAgo: TimeInterval) -> ElectionBroadcastPlanner.Sent {
        .init(state: state, at: start.addingTimeInterval(-secondsAgo))
    }

    // MARK: - Decisions

    @Test func `First push is high priority`() throws {
        let decision = planner.decide(try state(at: 0.3), lastSent: nil, now: start)
        #expect(decision?.event == .update)
        #expect(decision?.priority == 10)
    }

    @Test func `Already final result is not announced`() throws {
        #expect(planner.decide(try state(at: 1), lastSent: nil, now: start) == nil)
    }

    @Test func `Same state is not sent again`() throws {
        let current = try state(at: 0.3)
        #expect(planner.decide(current, lastSent: sent(current, secondsAgo: 600), now: start) == nil)
    }

    @Test func `Ordinary update waits for the interval`() throws {
        let previous = try state(at: 0.31)
        let current = try state(at: 0.32)
        #expect(planner.decide(current, lastSent: sent(previous, secondsAgo: 10), now: start) == nil)

        let decision = planner.decide(current, lastSent: sent(previous, secondsAgo: 30), now: start)
        #expect(decision?.event == .update)
        #expect(decision?.priority == 5)
    }

    @Test func `Crossing ten percent is high priority`() throws {
        let decision = planner.decide(try state(at: 0.41), lastSent: sent(try state(at: 0.39), secondsAgo: 60), now: start)
        #expect(decision?.priority == 10)
        #expect(decision?.reason == "40% counted")
    }

    @Test func `New leader is high priority`() throws {
        let before = try state(at: 0.51)
        var after = try state(at: 0.52)
        after.candidates.swapAt(0, 1)
        #expect(ElectionBroadcastPlanner.milestone(of: before) == ElectionBroadcastPlanner.milestone(of: after))

        #expect(planner.decide(after, lastSent: sent(before, secondsAgo: 10), now: start) == nil, "a new leader still waits for the interval")
        let decision = planner.decide(after, lastSent: sent(before, secondsAgo: 60), now: start)
        #expect(decision?.priority == 10)
        #expect(decision?.reason == "new leader")
    }

    @Test func `Final result ends right away ignoring the interval`() throws {
        let decision = planner.decide(try state(at: 1), lastSent: sent(try state(at: 0.99), secondsAgo: 1), now: start)
        #expect(decision?.event == .end)
        #expect(decision?.priority == 10)
    }

    @Test func `Edited final message is resent quietly`() throws {
        let ended = try state(at: 1)
        var edited = ended
        edited.finalMessage = "Nova mensagem"
        let decision = try #require(planner.decide(edited, lastSent: sent(ended, secondsAgo: 1), now: start))
        #expect(decision.event == .end)
        #expect(decision.priority == 5)
        #expect(!decision.alerts)

        let aps = try #require(try payloadJSON(edited, decision)["aps"] as? [String: Any])
        #expect(aps["alert"] == nil)
        #expect((aps["content-state"] as? [String: Any])?["finalMessage"] as? String == "Nova mensagem")
    }

    @Test func `Admin alert replaces the neutral one`() throws {
        let final = try state(at: 1)
        let onlyTitle = ElectionBroadcastPlanner.finalAlert(for: final, message: .init(text: "x", alertTitle: "Aeeee", alertBody: nil))
        #expect(onlyTitle.title == "Aeeee")
        #expect(onlyTitle.body.hasSuffix("vão para o 2º turno."), "the neutral body stays when only the title is set")

        let both = ElectionBroadcastPlanner.finalAlert(for: final, message: .init(text: "x", alertTitle: "A", alertBody: "B"))
        #expect(both == .init(title: "A", body: "B"))
    }

    @Test func `Replay restart after the end is sent right away`() throws {
        let decision = planner.decide(try state(at: 0), lastSent: sent(try state(at: 1), secondsAgo: 1), now: start)
        #expect(decision?.event == .update)
        #expect(decision?.priority == 10)
    }

    @Test func `Failed broadcast waits before retrying`() {
        let failedAt = start
        #expect(ElectionBroadcastPlanner.canRetry(lastFailureAt: nil, now: start, minInterval: 30))
        // Not on the next 10 s tick, as before.
        #expect(!ElectionBroadcastPlanner.canRetry(lastFailureAt: failedAt, now: start.addingTimeInterval(10), minInterval: 30))
        #expect(!ElectionBroadcastPlanner.canRetry(lastFailureAt: failedAt, now: start.addingTimeInterval(59), minInterval: 30))
        #expect(ElectionBroadcastPlanner.canRetry(lastFailureAt: failedAt, now: start.addingTimeInterval(60), minInterval: 30))
        // A longer push interval stretches the wait too.
        #expect(!ElectionBroadcastPlanner.canRetry(lastFailureAt: failedAt, now: start.addingTimeInterval(90), minInterval: 120))
    }

    // MARK: - Payload

    @Test func `Update payload`() async throws {
        try await withTestApp { app in
            let current = try state(at: 0.5)
            let decision = ElectionBroadcastPlanner.Decision(event: .update, priority: 5, reason: "progress")
            let json = try payloadJSON(current, decision)
            let aps = try #require(json["aps"] as? [String: Any])

            #expect(Set(aps.keys) == ["timestamp", "event", "content-state", "stale-date"])
            #expect(aps["event"] as? String == "update")
            #expect(aps["timestamp"] as? Int == 1_790_000_000)
            #expect(aps["stale-date"] as? Int == 1_790_000_000 + 15 * 60)
            #expect(ElectionBroadcastPlanner.expiration(for: decision, now: start) == 1_790_000_000 + 15 * 60)

            // Must decode exactly like the app's ContentState.
            let contentState = try #require(aps["content-state"] as? [String: Any])
            #expect(Set(contentState.keys) == ["sectionsCountedPercent", "isFinal", "updatedAt", "candidates"])
            let decoded = try JSONDecoder().decode(ElectionLiveContentState.self, from: JSONSerialization.data(withJSONObject: contentState))
            #expect(decoded == current)
        }
    }

    @Test func `End payload has dismissal date and alert`() throws {
        let decision = ElectionBroadcastPlanner.Decision(event: .end, priority: 10, reason: "final result")
        let aps = try #require(try payloadJSON(try state(at: 1), decision)["aps"] as? [String: Any])

        #expect(Set(aps.keys) == ["timestamp", "event", "content-state", "dismissal-date", "alert"])
        #expect(aps["event"] as? String == "end")
        #expect(aps["dismissal-date"] as? Int == 1_790_000_000 + 4 * 60 * 60)
        let alert = try #require(aps["alert"] as? [String: String])
        #expect(alert["title"] == "Apuração encerrada")
        // The simulation goes to a runoff.
        #expect(try #require(alert["body"]).hasSuffix("vão para o 2º turno."))
    }

    @Test func `Payload fits in broadcast limit`() throws {
        let decision = ElectionBroadcastPlanner.Decision(event: .end, priority: 10, reason: "final result")
        let data = try JSONEncoder().encode(ElectionBroadcastPlanner.payload(for: try state(at: 1), decision: decision, now: start))
        #expect(data.count < 5_120)
    }

    @Test func `Elected alert`() throws {
        let winner = ElectionLiveContentState.Candidate(number: 13, name: "FULANO", party: "ABC", percent: 52.31, status: .elected, colorHex: nil)
        let other = ElectionLiveContentState.Candidate(number: 22, name: "CICLANO", party: "XYZ", percent: 47.69, status: .notElected, colorHex: nil)
        var content = try state(at: 1)
        content.candidates = [winner, other]
        #expect(ElectionBroadcastPlanner.finalAlert(for: content).body == "FULANO (ABC) vence com 52,31% dos votos válidos.")
    }

    private func payloadJSON(_ state: ElectionLiveContentState, _ decision: ElectionBroadcastPlanner.Decision) throws -> [String: Any] {
        let data = try JSONEncoder().encode(ElectionBroadcastPlanner.payload(for: state, decision: decision, now: start))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
