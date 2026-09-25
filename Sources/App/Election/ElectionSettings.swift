import Foundation

/// Everything the admin can change at runtime, stored as one JSON blob in `ServerSetting`
/// under `election-settings`. Switching from the simulation to the official feed on election
/// day is a settings change, not a deploy.
struct ElectionSettings: Codable, Equatable, Sendable {

    enum Source: String, Codable {
        /// TSE test environment (simulado2026).
        case simulation
        /// Real results.
        case official
        /// Fake count built from the final simulation result, see `ElectionReplay`.
        case replay
    }

    /// Public launch switch. Testers can use the feature before this through the app's
    /// `electionLiveActivity` feature flag.
    var enabled: Bool = false
    var source: Source = .simulation
    var round: Int = 1
    /// APNs broadcast channel the Live Activities subscribe to.
    var channelId: String?
    /// "#RRGGBB" by ballot number.
    var candidateColors: [String: String] = [:]
    /// Seconds since 1970. Replay progress is measured from here.
    var replayStartedAt: Double?
    var replayDurationMinutes: Double = 20

    static let settingKey = "election-settings"

    var endpoint: TSEEndpoint {
        source == .official ? .official : .simulation
    }

    func replayProgress(at date: Date) -> Double {
        guard let replayStartedAt, replayDurationMinutes > 0 else { return 0 }
        let elapsed = date.timeIntervalSince1970 - replayStartedAt
        return min(max(elapsed / (replayDurationMinutes * 60), 0), 1)
    }

    /// Fields left nil keep their current value.
    struct Update: Codable {
        var enabled: Bool?
        var source: Source?
        var round: Int?
        var channelId: String?
        var candidateColors: [String: String]?
        var replayDurationMinutes: Double?
        /// Starts (or restarts) the replay from 0%.
        var restartReplay: Bool?
    }

    func applying(_ update: Update, now: Date = .now) -> ElectionSettings {
        var settings = self
        if let enabled = update.enabled { settings.enabled = enabled }
        if let source = update.source { settings.source = source }
        if let round = update.round { settings.round = round }
        if let channelId = update.channelId { settings.channelId = channelId.isEmpty ? nil : channelId }
        if let candidateColors = update.candidateColors { settings.candidateColors = candidateColors }
        if let replayDurationMinutes = update.replayDurationMinutes { settings.replayDurationMinutes = replayDurationMinutes }
        if update.restartReplay == true || (update.source == .replay && source != .replay) {
            settings.replayStartedAt = now.timeIntervalSince1970
        }
        return settings
    }
}
