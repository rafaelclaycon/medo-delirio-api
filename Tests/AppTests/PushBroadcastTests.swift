@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation
import APNSwift

struct PushBroadcastTests {

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

    @Test func `Runner counts each outcome and finishes`() async throws {
        let store = PushBroadcastStore()
        let broadcast = status(total: 3)
        let began = await store.begin(broadcast)
        #expect(began)
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
        let final = try #require(stored)
        #expect(final.state == .finished)
        #expect(final.processed == 3)
        #expect(final.sent == 1)
        #expect(final.removedTokens == 1)
        #expect(final.failed == 1)
        #expect(final.recentErrors == ["device-2: timeout"])
        #expect(final.finishedAt != nil)
        let removedIds = await removed.installIds
        #expect(removedIds == ["device-1"])
    }

    @Test func `Tokens for another topic count as invalid`() {
        let reasons: [APNSwiftError.ResponseErrorMessage] = [.badDeviceToken, .unregistered, .deviceTokenNotForTopic]
        for reason in reasons {
            #expect(PushTokenErrors.isInvalidToken(APNSwiftError.ResponseError.badRequest(reason)), "\(reason)")
        }
        #expect(!PushTokenErrors.isInvalidToken(APNSwiftError.ResponseError.badRequest(.tooManyRequests)))
    }

    @Test func `Runner stops before the next device when cancelled`() async throws {
        let store = PushBroadcastStore()
        let broadcast = status(total: 5)
        let began = await store.begin(broadcast)
        #expect(began)

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
        let final = try #require(stored)
        #expect(final.state == .cancelled)
        #expect(final.sent == 2)
        #expect(final.total == 5)
    }

    // MARK: - Store

    @Test func `Only one broadcast sends at a time`() async {
        let store = PushBroadcastStore()
        let first = status(total: 1)
        let beganFirst = await store.begin(first)
        let beganSecondWhileSending = await store.begin(status(total: 1))
        #expect(beganFirst)
        #expect(!beganSecondWhileSending)

        await store.finish(id: first.id, as: .finished)
        let beganAfterFinishing = await store.begin(status(total: 1))
        #expect(beganAfterFinishing)
    }

    @Test func `Cancelling a finished broadcast changes nothing`() async throws {
        let store = PushBroadcastStore()
        let broadcast = status(total: 1)
        let began = await store.begin(broadcast)
        #expect(began)
        await store.finish(id: broadcast.id, as: .finished)

        let cancelled = await store.requestCancel(id: broadcast.id)
        let isCancelRequested = await store.isCancelRequested(id: broadcast.id)
        let unknown = await store.requestCancel(id: UUID())
        #expect(cancelled?.state == .finished)
        #expect(!isCancelRequested)
        #expect(unknown == nil)
    }

    // MARK: - Routes

    @Test func `Audience only counts devices with a token`() async throws {
        try await withTestApp { app in
            try await PushDevice(installId: "a", pushToken: "token-a").save(on: app.db)
            try await PushDevice(installId: "b", pushToken: "token-b").save(on: app.db)
            try await PushDevice(installId: "c", pushToken: "").save(on: app.db)
            try await PushDevice(installId: "d", pushToken: nil).save(on: app.db)

            try await app.testing().test(.GET, "api/v4/push-audience/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(PushAudience.self).deviceCount == 2)
            }
        }
    }

    @Test func `Broadcast routes need the password`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v4/push-broadcasts/wrong") { res async in
                #expect(res.status == .unauthorized)
            }
            try await app.testing().test(.POST, "api/v4/push-broadcasts/wrong", beforeRequest: { req in
                try req.content.encode(PushBroadcastRequest(title: "Oi", body: "Tchau"))
            }) { res async in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test func `Broadcast needs a title and body`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.POST, "api/v4/push-broadcasts/\(TestEnvironment.testPassword)", beforeRequest: { req in
                try req.content.encode(PushBroadcastRequest(title: "  ", body: "Texto"))
            }) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test func `Broadcast to no devices finishes and shows in the history`() async throws {
        try await withTestApp { app in
            var started: PushBroadcastStatus?
            try await app.testing().test(.POST, "api/v4/push-broadcasts/\(TestEnvironment.testPassword)", beforeRequest: { req in
                try req.content.encode(PushBroadcastRequest(title: "Oi", body: "Tchau"))
            }) { res async throws in
                #expect(res.status == .accepted)
                started = try res.content.decode(PushBroadcastStatus.self)
            }
            let broadcast = try #require(started)
            #expect(broadcast.total == 0)

            // The run is in a background task; with nothing to send it ends almost at once.
            for _ in 0..<50 where await app.pushBroadcastStore.status(id: broadcast.id)?.state == .sending {
                try await Task.sleep(for: .milliseconds(20))
            }

            try await app.testing().test(.GET, "api/v4/push-broadcast/\(broadcast.id)/\(TestEnvironment.testPassword)") { res async throws in
                #expect(try res.content.decode(PushBroadcastStatus.self).state == .finished)
            }
            try await app.testing().test(.GET, "api/v4/push-broadcasts/\(TestEnvironment.testPassword)") { res async throws in
                #expect(try res.content.decode([PushBroadcastStatus].self).map(\.id) == [broadcast.id])
            }
        }
    }
}
