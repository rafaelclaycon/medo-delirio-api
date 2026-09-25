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

    enum BroadcastMode: String, Codable {
        /// No pushes at all.
        case off
        /// Decides every push as if live but only logs the payload.
        case dryRun
        /// Sends to APNs.
        case live
    }

    /// Beta and production are different apps to APNs, so each needs its own channel.
    static let productionBundleId = "com.rafaelschmitt.MedoDelirioBrasilia"
    static let betaBundleId = "com.rafaelschmitt.MedoDelirioBrasilia.beta"
    static let appBundleIds = [productionBundleId, betaBundleId]

    /// Public launch switch. Testers can use the feature before this through the app's
    /// `electionLiveActivity` feature flag.
    var enabled: Bool = false
    var source: Source = .simulation
    var round: Int = 1
    /// APNs broadcast channel the Live Activities subscribe to, by app bundle ID. Channels
    /// also belong to one APNs environment (`APNS_ENVIRONMENT`).
    var channelIds: [String: String] = [:]
    var broadcastMode: BroadcastMode = .dryRun
    /// Ordinary updates go out at most this often. The final result isn't held back.
    var minPushIntervalSeconds: Double = 30
    /// "#RRGGBB" by ballot number.
    var candidateColors: [String: String] = [:]
    /// Seconds since 1970. Replay progress is measured from here.
    var replayStartedAt: Double?
    var replayDurationMinutes: Double = 20

    static let settingKey = "election-settings"

    init(
        enabled: Bool = false,
        source: Source = .simulation,
        round: Int = 1,
        channelIds: [String: String] = [:],
        broadcastMode: BroadcastMode = .dryRun,
        minPushIntervalSeconds: Double = 30,
        candidateColors: [String: String] = [:],
        replayStartedAt: Double? = nil,
        replayDurationMinutes: Double = 20
    ) {
        self.enabled = enabled
        self.source = source
        self.round = round
        self.channelIds = channelIds
        self.broadcastMode = broadcastMode
        self.minPushIntervalSeconds = minPushIntervalSeconds
        self.candidateColors = candidateColors
        self.replayStartedAt = replayStartedAt
        self.replayDurationMinutes = replayDurationMinutes
    }

    /// Missing keys fall back to the defaults, so adding a field doesn't break the JSON
    /// already saved in the database.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ElectionSettings()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? defaults.source
        round = try container.decodeIfPresent(Int.self, forKey: .round) ?? defaults.round
        channelIds = try container.decodeIfPresent([String: String].self, forKey: .channelIds) ?? defaults.channelIds
        broadcastMode = try container.decodeIfPresent(BroadcastMode.self, forKey: .broadcastMode) ?? defaults.broadcastMode
        minPushIntervalSeconds = try container.decodeIfPresent(Double.self, forKey: .minPushIntervalSeconds) ?? defaults.minPushIntervalSeconds
        candidateColors = try container.decodeIfPresent([String: String].self, forKey: .candidateColors) ?? defaults.candidateColors
        replayStartedAt = try container.decodeIfPresent(Double.self, forKey: .replayStartedAt)
        replayDurationMinutes = try container.decodeIfPresent(Double.self, forKey: .replayDurationMinutes) ?? defaults.replayDurationMinutes
    }

    /// A channel only works for the app it was created for, so there's no fallback between
    /// apps. A client that doesn't say which app it is gets production's.
    func channelId(forBundleId bundleId: String?) -> String? {
        channelIds[bundleId ?? Self.productionBundleId]
    }

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
        /// Merged by bundle ID. An empty string removes that bundle's channel.
        var channelIds: [String: String]?
        var broadcastMode: BroadcastMode?
        var minPushIntervalSeconds: Double?
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
        for (bundleId, channelId) in update.channelIds ?? [:] {
            settings.channelIds[bundleId] = channelId.isEmpty ? nil : channelId
        }
        if let broadcastMode = update.broadcastMode { settings.broadcastMode = broadcastMode }
        if let minPushIntervalSeconds = update.minPushIntervalSeconds { settings.minPushIntervalSeconds = minPushIntervalSeconds }
        if let candidateColors = update.candidateColors { settings.candidateColors = candidateColors }
        if let replayDurationMinutes = update.replayDurationMinutes { settings.replayDurationMinutes = replayDurationMinutes }
        if update.restartReplay == true || (update.source == .replay && source != .replay) {
            settings.replayStartedAt = now.timeIntervalSince1970
        }
        return settings
    }
}
