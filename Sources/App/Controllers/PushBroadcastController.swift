import Vapor
import Fluent
import APNS

/// Pushes written by hand in MedoHelper. Sending returns right away and the broadcast
/// carries on in the background; MedoHelper polls its status to draw the progress.
struct PushBroadcastController {

    /// Was half a second on the blocking endpoint, which made a broadcast to everyone
    /// take hours. Matches the silent content update pushes.
    static let pauseBetweenDevices: Duration = .milliseconds(50)

    func postBroadcastHandlerV4(req: Request) async throws -> Response {
        try checkPassword(req)
        let input = try req.content.decode(PushBroadcastRequest.self)
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = input.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else {
            throw Abort(.badRequest, reason: "Title and body are required")
        }

        let targets = try await Self.targets(on: req.db)
        let status = PushBroadcastStatus(
            id: UUID(),
            title: title,
            body: body,
            state: .sending,
            total: targets.count,
            processed: 0,
            sent: 0,
            failed: 0,
            removedTokens: 0,
            startedAt: .now,
            finishedAt: nil,
            recentErrors: []
        )

        let app = req.application
        let store = app.pushBroadcastStore
        guard await store.begin(status) else {
            throw Abort(.conflict, reason: "Another broadcast is still sending")
        }
        req.logger.info("Push broadcast \(status.id): sending to \(targets.count) devices")

        let runner = PushBroadcastRunner(
            store: store,
            pauseBetweenDevices: Self.pauseBetweenDevices,
            send: { token in
                try await app.apns.send(.init(title: title, body: body), to: token).get()
            },
            removeDevice: { installId in
                try? await PushDevice.query(on: app.db)
                    .filter(\PushDevice.$installId, .equal, installId)
                    .delete()
            }
        )
        // Not tied to the request: it outlives it by however long the broadcast takes.
        Task {
            await runner.run(id: status.id, targets: targets)
            if let final = await store.status(id: status.id) {
                app.logger.info("Push broadcast \(final.id): \(final.state.rawValue), \(final.sent) sent, \(final.failed) failed, \(final.removedTokens) tokens removed")
            }
        }

        return try await status.encodeResponse(status: .accepted, for: req)
    }

    func getBroadcastsHandlerV4(req: Request) async throws -> [PushBroadcastStatus] {
        try checkPassword(req)
        return await req.application.pushBroadcastStore.all()
    }

    func getBroadcastHandlerV4(req: Request) async throws -> PushBroadcastStatus {
        try checkPassword(req)
        guard let status = await req.application.pushBroadcastStore.status(id: try broadcastId(req)) else {
            throw Abort(.notFound, reason: "Broadcast not found")
        }
        return status
    }

    /// The broadcast stops before its next device, so the status returned may still say
    /// `sending` for a moment.
    func postCancelBroadcastHandlerV4(req: Request) async throws -> PushBroadcastStatus {
        try checkPassword(req)
        guard let status = await req.application.pushBroadcastStore.requestCancel(id: try broadcastId(req)) else {
            throw Abort(.notFound, reason: "Broadcast not found")
        }
        return status
    }

    /// How many devices a broadcast would reach right now.
    func getAudienceHandlerV4(req: Request) async throws -> PushAudience {
        try checkPassword(req)
        return PushAudience(deviceCount: try await Self.targets(on: req.db).count)
    }

    // MARK: - Helpers

    private func checkPassword(_ req: Request) throws {
        guard req.parameters.get("password") == ReleaseConfigs.Passwords.sendNotificationPassword else {
            throw Abort(.unauthorized)
        }
    }

    private func broadcastId(_ req: Request) throws -> UUID {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid broadcast id")
        }
        return id
    }

    /// Every device with a push token.
    static func targets(on db: Database) async throws -> [PushBroadcastRunner.Target] {
        try await PushDevice.query(on: db).all().compactMap { device in
            guard let token = device.pushToken, !token.isEmpty else { return nil }
            return PushBroadcastRunner.Target(installId: device.installId, token: token)
        }
    }
}
