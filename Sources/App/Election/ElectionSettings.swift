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
    /// The replay moves in jumps this far apart, like new TSE files. 0 moves every poll.
    var replayStepSeconds: Double = 60
    /// Uses the simulation result built into the server instead of fetching it from the TSE.
    var replayOffline: Bool = false

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
        replayDurationMinutes: Double = 20,
        replayStepSeconds: Double = 60,
        replayOffline: Bool = false
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
        self.replayStepSeconds = replayStepSeconds
        self.replayOffline = replayOffline
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
        replayStepSeconds = try container.decodeIfPresent(Double.self, forKey: .replayStepSeconds) ?? defaults.replayStepSeconds
        replayOffline = try container.decodeIfPresent(Bool.self, forKey: .replayOffline) ?? defaults.replayOffline
    }

    /// A channel only works for the app it was created for, so there's no fallback between
    /// apps. A client that doesn't say which app it is gets production's.
    func channelId(forBundleId bundleId: String?) -> String? {
        channelIds[bundleId ?? Self.productionBundleId]
    }

    var endpoint: TSEEndpoint {
        source == .official ? .official : .simulation
    }

    struct ReplayPosition: Equatable {
        /// Share of the replay duration elapsed at the current step, 0 to 1.
        let progress: Double
        /// When the current step was "published", shown as the TSE totalization time.
        let publishedAt: Date
    }

    /// Where the replay is at `date`. Only moves at every `replayStepSeconds`, and the last
    /// step always lands on the end of the duration.
    func replayPosition(at date: Date) -> ReplayPosition {
        guard let replayStartedAt, replayDurationMinutes > 0 else {
            return ReplayPosition(progress: 0, publishedAt: date)
        }
        let duration = replayDurationMinutes * 60
        let elapsed = min(max(date.timeIntervalSince1970 - replayStartedAt, 0), duration)
        let stepped = elapsed < duration && replayStepSeconds > 0
            ? (elapsed / replayStepSeconds).rounded(.down) * replayStepSeconds
            : elapsed
        return ReplayPosition(
            progress: stepped / duration,
            publishedAt: Date(timeIntervalSince1970: replayStartedAt + stepped)
        )
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
        var replayStepSeconds: Double?
        var replayOffline: Bool?
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
        if let replayStepSeconds = update.replayStepSeconds { settings.replayStepSeconds = replayStepSeconds }
        if let replayOffline = update.replayOffline { settings.replayOffline = replayOffline }
        if update.restartReplay == true || (update.source == .replay && source != .replay) {
            settings.replayStartedAt = now.timeIntervalSince1970
        }
        return settings
    }
}
