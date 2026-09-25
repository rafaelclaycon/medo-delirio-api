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
    }

    // MARK: - Public

    /// Always returns the latest state, even while `enabled` is off: testers with the
    /// app's feature flag need it before the public launch.
    func getLiveHandlerV4(req: Request) async throws -> LiveResponse {
        let settings = try await ElectionSettingsRepository.load(db: req.db)
        let snapshot = await req.application.electionLiveStore.snapshot
        return LiveResponse(
            enabled: settings.enabled,
            channelId: settings.channelId,
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
            state: snapshot.map { ElectionLiveContentState(snapshot: $0, candidateColors: settings.candidateColors) }
        )
    }

    /// Partial update: send only the fields to change, e.g. `{"source": "official"}`.
    func postSettingsHandlerV4(req: Request) async throws -> ElectionSettings {
        try checkPassword(req)
        let update = try req.content.decode(ElectionSettings.Update.self)
        if let round = update.round, ![1, 2].contains(round) {
            throw Abort(.badRequest, reason: "round must be 1 or 2")
        }
        let settings = try await ElectionSettingsRepository.load(db: req.db).applying(update)
        try await ElectionSettingsRepository.save(settings, db: req.db)
        req.logger.info("Election settings updated: enabled=\(settings.enabled) source=\(settings.source.rawValue) round=\(settings.round)")
        return settings
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
