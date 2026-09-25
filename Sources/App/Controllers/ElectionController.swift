//
//  ElectionController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 24/09/26.
//

import Vapor

extension ElectionSettings: Content { }

struct ElectionController {

    /// Consumed by the app (`ElectionLiveInfo`) when starting the Live Activity.
    struct LiveResponse: Content {
        let enabled: Bool
        let channelId: String?
        let round: Int
        let state: ElectionLiveContentState?
    }

    struct StatusResponse: Content {
        let settings: ElectionSettings
        let cycle: String?
        let electionCode: String?
        let generationId: String?
        let sectionsCountedPercent: Double?
        let isFinal: Bool?
        let lastFetchAt: Date?
        let lastError: String?
        let state: ElectionLiveContentState?
        let lastBroadcastAt: Date?
        let lastBroadcastEvent: String?
        let lastBroadcastPriority: Int?
        let lastBroadcastReason: String?
        let lastBroadcastError: String?
    }

    struct ChannelsResponse: Content {
        let apnsEnvironment: String
        /// What the settings point to, by bundle ID.
        let configured: [String: String]
        /// Every channel APNs knows for each bundle ID.
        let onAPNs: [String: [String]]
        /// Per bundle ID, when listing on APNs failed.
        let errors: [String: String]
    }

    // MARK: - Public

    /// Always returns the latest state, even while `enabled` is off: testers with the
    /// app's feature flag need it before the public launch.
    ///
    /// `?bundleId=` picks the channel: beta and production are different apps to APNs.
    func getLiveHandlerV4(req: Request) async throws -> LiveResponse {
        let settings = try await ElectionSettingsRepository.load(db: req.db)
        let snapshot = await req.application.electionLiveStore.snapshot
        return LiveResponse(
            enabled: settings.enabled,
            channelId: settings.channelId(forBundleId: req.query[String.self, at: "bundleId"]),
            round: settings.round,
            state: snapshot.map { ElectionLiveContentState(snapshot: $0, candidateColors: settings.candidateColors) }
        )
    }

    // MARK: - Admin

    func getStatusHandlerV4(req: Request) async throws -> StatusResponse {
        try checkPassword(req)
        let settings = try await ElectionSettingsRepository.load(db: req.db)
        let store = req.application.electionLiveStore
        let snapshot = await store.snapshot
        let resolved = await store.resolvedElection
        return StatusResponse(
            settings: settings,
            cycle: resolved?.cycle,
            electionCode: resolved?.electionCode,
            generationId: snapshot?.generationId,
            sectionsCountedPercent: snapshot?.sectionsCountedPercent,
            isFinal: snapshot?.isFinal,
            lastFetchAt: await store.lastFetchAt,
            lastError: await store.lastError,
            state: snapshot.map { ElectionLiveContentState(snapshot: $0, candidateColors: settings.candidateColors) },
            lastBroadcastAt: await store.lastBroadcast?.at,
            lastBroadcastEvent: await store.lastBroadcastDecision?.event.rawValue,
            lastBroadcastPriority: await store.lastBroadcastDecision?.priority,
            lastBroadcastReason: await store.lastBroadcastDecision?.reason,
            lastBroadcastError: await store.lastBroadcastError
        )
    }

    /// Partial update: send only the fields to change, e.g. `{"source": "official"}`.
    func postSettingsHandlerV4(req: Request) async throws -> ElectionSettings {
        try checkPassword(req)
        let update = try req.content.decode(ElectionSettings.Update.self)
        if let round = update.round, ![1, 2].contains(round) {
            throw Abort(.badRequest, reason: "round must be 1 or 2")
        }
        if let interval = update.minPushIntervalSeconds, interval < ElectionPollingService.pollingInterval {
            throw Abort(.badRequest, reason: "minPushIntervalSeconds can't be below the \(Int(ElectionPollingService.pollingInterval))s polling interval")
        }
        let settings = try await ElectionSettingsRepository.load(db: req.db).applying(update)
        try await ElectionSettingsRepository.save(settings, db: req.db)
        req.logger.info("Election settings updated: enabled=\(settings.enabled) source=\(settings.source.rawValue) round=\(settings.round)")
        return settings
    }

    /// Creates the broadcast channel of each app that doesn't have one yet, in the current
    /// APNs environment, and saves it in the settings. To replace a channel, clear it first
    /// with `{"channelIds": {"<bundle ID>": ""}}`.
    func postChannelsHandlerV4(req: Request) async throws -> ElectionSettings {
        try checkPassword(req)
        var settings = try await ElectionSettingsRepository.load(db: req.db)
        let client = APNsBroadcastClient(app: req.application)
        for bundleId in ElectionSettings.appBundleIds where settings.channelIds[bundleId] == nil {
            let channelId = try await client.createChannel(bundleId: bundleId)
            settings.channelIds[bundleId] = channelId
            // Saved one by one so a failure on the second app doesn't lose the first channel.
            try await ElectionSettingsRepository.save(settings, db: req.db)
            req.logger.info("Election channel created for \(bundleId) in \(APNsBroadcastClient.environmentName): \(channelId)")
        }
        return settings
    }

    func getChannelsHandlerV4(req: Request) async throws -> ChannelsResponse {
        try checkPassword(req)
        let settings = try await ElectionSettingsRepository.load(db: req.db)
        let client = APNsBroadcastClient(app: req.application)
        var onAPNs: [String: [String]] = [:]
        var errors: [String: String] = [:]
        for bundleId in ElectionSettings.appBundleIds {
            do {
                onAPNs[bundleId] = try await client.listChannels(bundleId: bundleId)
            } catch {
                errors[bundleId] = String(describing: error)
            }
        }
        return ChannelsResponse(
            apnsEnvironment: APNsBroadcastClient.environmentName,
            configured: settings.channelIds,
            onAPNs: onAPNs,
            errors: errors
        )
    }

    private func checkPassword(_ req: Request) throws {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.electionPassword else {
            throw Abort(.forbidden)
        }
    }
}
