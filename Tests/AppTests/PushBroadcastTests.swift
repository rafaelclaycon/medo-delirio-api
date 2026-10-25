@testable import App
import XCTVapor
import Fluent
import Foundation

final class PushBroadcastTests: XCTestCase {

    private struct SendError: Error, CustomStringConvertible {
        let description: String
    }

    private actor Removed {
        var installIds: [String] = []
        func append(_ installId: String) { installIds.append(installId) }
    }

    private func status(total: Int) -> PushBroadcastStatus {
        PushBroadcastStatus(
            id: UUID(), title: "Título", body: "Texto", state: .sending,
            total: total, processed: 0, sent: 0, failed: 0, removedTokens: 0,
            startedAt: .now, finishedAt: nil, recentErrors: []
        )
    }

    private func targets(_ count: Int) -> [PushBroadcastRunner.Target] {
        (0..<count).map { .init(installId: "device-\($0)", token: "token-\($0)") }
    }

    // MARK: - Runner

    func testRunnerCountsEachOutcomeAndFinishes() async throws {
        let store = PushBroadcastStore()
        let broadcast = status(total: 3)
        let began = await store.begin(broadcast)
        XCTAssertTrue(began)
        let removed = Removed()

        let runner = PushBroadcastRunner(
            store: store,
            pauseBetweenDevices: .zero,
            send: { token in
                switch token {
                case "token-1": throw SendError(description: "APNSError: Unregistered")
                case "token-2": throw SendError(description: "timeout")
                default: return
                }
            },
            removeDevice: { installId in await removed.append(installId) }
        )
        await runner.run(id: broadcast.id, targets: targets(3))

        let stored = await store.status(id: broadcast.id)
        let final = try XCTUnwrap(stored)
        XCTAssertEqual(final.state, .finished)
        XCTAssertEqual(final.processed, 3)
        XCTAssertEqual(final.sent, 1)
        XCTAssertEqual(final.removedTokens, 1)
        XCTAssertEqual(final.failed, 1)
        XCTAssertEqual(final.recentErrors, ["device-2: timeout"])
        XCTAssertNotNil(final.finishedAt)
        let removedIds = await removed.installIds
        XCTAssertEqual(removedIds, ["device-1"])
    }

    func testRunnerStopsBeforeTheNextDeviceWhenCancelled() async throws {
        let store = PushBroadcastStore()
        let broadcast = status(total: 5)
        let began = await store.begin(broadcast)
        XCTAssertTrue(began)

        let runner = PushBroadcastRunner(
            store: store,
            pauseBetweenDevices: .zero,
            send: { token in
                if token == "token-1" {
                    _ = await store.requestCancel(id: broadcast.id)
                }
            },
            removeDevice: { _ in }
        )
        await runner.run(id: broadcast.id, targets: targets(5))

        let stored = await store.status(id: broadcast.id)
        let final = try XCTUnwrap(stored)
        XCTAssertEqual(final.state, .cancelled)
        XCTAssertEqual(final.sent, 2)
        XCTAssertEqual(final.total, 5)
    }

    // MARK: - Store

    func testOnlyOneBroadcastSendsAtATime() async {
        let store = PushBroadcastStore()
        let first = status(total: 1)
        let beganFirst = await store.begin(first)
        let beganSecondWhileSending = await store.begin(status(total: 1))
        XCTAssertTrue(beganFirst)
        XCTAssertFalse(beganSecondWhileSending)

        await store.finish(id: first.id, as: .finished)
        let beganAfterFinishing = await store.begin(status(total: 1))
        XCTAssertTrue(beganAfterFinishing)
    }

    func testCancellingAFinishedBroadcastChangesNothing() async throws {
        let store = PushBroadcastStore()
        let broadcast = status(total: 1)
        let began = await store.begin(broadcast)
        XCTAssertTrue(began)
        await store.finish(id: broadcast.id, as: .finished)

        let cancelled = await store.requestCancel(id: broadcast.id)
        let isCancelRequested = await store.isCancelRequested(id: broadcast.id)
        let unknown = await store.requestCancel(id: UUID())
        XCTAssertEqual(cancelled?.state, .finished)
        XCTAssertFalse(isCancelRequested)
        XCTAssertNil(unknown)
    }

    // MARK: - Routes

    private func withApp(_ test: (Application) async throws -> Void) async throws {
        TestEnvironment.configurePasswords()
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    func testAudienceOnlyCountsDevicesWithAToken() async throws {
        try await withApp { app in
            try await PushDevice(installId: "a", pushToken: "token-a").save(on: app.db)
            try await PushDevice(installId: "b", pushToken: "token-b").save(on: app.db)
            try await PushDevice(installId: "c", pushToken: "").save(on: app.db)
            try await PushDevice(installId: "d", pushToken: nil).save(on: app.db)

            try await app.test(.GET, "api/v4/push-audience/\(TestEnvironment.testPassword)") { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode(PushAudience.self).deviceCount, 2)
            }
        }
    }

    func testBroadcastRoutesNeedThePassword() async throws {
        try await withApp { app in
            try await app.test(.GET, "api/v4/push-broadcasts/wrong") { res async in
                XCTAssertEqual(res.status, .unauthorized)
            }
            try await app.test(.POST, "api/v4/push-broadcasts/wrong", beforeRequest: { req in
                try req.content.encode(PushBroadcastRequest(title: "Oi", body: "Tchau"))
            }) { res async in
                XCTAssertEqual(res.status, .unauthorized)
            }
        }
    }

    func testBroadcastNeedsATitleAndBody() async throws {
        try await withApp { app in
            try await app.test(.POST, "api/v4/push-broadcasts/\(TestEnvironment.testPassword)", beforeRequest: { req in
                try req.content.encode(PushBroadcastRequest(title: "  ", body: "Texto"))
            }) { res async in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }

    func testBroadcastToNoDevicesFinishesAndShowsInTheHistory() async throws {
        try await withApp { app in
            var started: PushBroadcastStatus?
            try await app.test(.POST, "api/v4/push-broadcasts/\(TestEnvironment.testPassword)", beforeRequest: { req in
                try req.content.encode(PushBroadcastRequest(title: "Oi", body: "Tchau"))
            }) { res async throws in
                XCTAssertEqual(res.status, .accepted)
                started = try res.content.decode(PushBroadcastStatus.self)
            }
            let broadcast = try XCTUnwrap(started)
            XCTAssertEqual(broadcast.total, 0)

            // The run is in a background task; with nothing to send it ends almost at once.
            for _ in 0..<50 where await app.pushBroadcastStore.status(id: broadcast.id)?.state == .sending {
                try await Task.sleep(for: .milliseconds(20))
            }

            try await app.test(.GET, "api/v4/push-broadcast/\(broadcast.id)/\(TestEnvironment.testPassword)") { res async throws in
                XCTAssertEqual(try res.content.decode(PushBroadcastStatus.self).state, .finished)
            }
            try await app.test(.GET, "api/v4/push-broadcasts/\(TestEnvironment.testPassword)") { res async throws in
                XCTAssertEqual(try res.content.decode([PushBroadcastStatus].self).map(\.id), [broadcast.id])
            }
        }
    }
}
