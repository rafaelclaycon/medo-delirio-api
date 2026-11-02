@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct PlayLogControllerTests {

    /// A fresh app with this suite's fixtures already in place.
    private func withSeededApp(_ test: (Application) async throws -> Void) async throws {
        try await withTestApp { app in
            try await Self.makeContent(id: soundId, type: .sound).create(on: app.db)
            try await Self.makeContent(id: songId, type: .song).create(on: app.db)
            try await test(app)
        }
    }

    private let soundId = UUID()
    private let songId = UUID()

    @Test func `Stores plays and takes content type from the catalog`() async throws {
        try await withSeededApp { app in
            let batch = Self.batch([
                Self.play(contentId: soundId),
                Self.play(contentId: songId, isAutoplay: true)
            ])

            try await post(batch, on: app) { res in
                #expect(res.status == .ok)
                let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
                #expect(body.received == 2)
                #expect(body.stored == 2)
            }

            let logs = try await PlayLog.query(on: app.db).all()
            #expect(logs.count == 2)
            let song = try #require(logs.first { $0.contentId == songId.uuidString })
            #expect(song.contentType == ContentType.song.rawValue)
            #expect(song.isAutoplay)
            #expect(song.installId == "install-1")
            #expect(song.appVersion == "13.2")
        }
    }

    @Test func `Resending a batch stores it once`() async throws {
        try await withSeededApp { app in
            let batch = Self.batch([Self.play(contentId: soundId), Self.play(contentId: songId)])

            try await post(batch, on: app) { res in #expect(res.status == .ok) }
            try await post(batch, on: app) { res in
                #expect(res.status == .ok)
                let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
                #expect(body.stored == 0)
            }

            let count = try await PlayLog.query(on: app.db).count()
            #expect(count == 2)
        }
    }

    @Test func `Drops bad rows without failing the batch`() async throws {
        try await withSeededApp { app in
            let duplicate = Self.play(contentId: soundId)
            let batch = Self.batch([
                duplicate,
                duplicate,
                Self.play(contentId: UUID()),
                PlayLogController.Play(id: "not-a-uuid", contentId: soundId.uuidString, dateTime: Self.dateTime, isAutoplay: false),
                PlayLogController.Play(id: UUID().uuidString, contentId: soundId.uuidString, dateTime: "yesterday", isAutoplay: false),
                Self.play(contentId: songId)
            ])

            try await post(batch, on: app) { res in
                #expect(res.status == .ok)
                let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
                #expect(body.received == 6)
                #expect(body.stored == 2)
            }
        }
    }

    @Test func `Lowercase content id is stored in catalog casing`() async throws {
        try await withSeededApp { app in
            let play = PlayLogController.Play(
                id: UUID().uuidString,
                contentId: soundId.uuidString.lowercased(),
                dateTime: Self.dateTime,
                isAutoplay: false
            )

            try await post(Self.batch([play]), on: app) { res in #expect(res.status == .ok) }

            let log = try await PlayLog.query(on: app.db).first()
            #expect(log?.contentId == soundId.uuidString)
        }
    }

    @Test func `Rejects oversized batch`() async throws {
        try await withSeededApp { app in
            let plays = (0...PlayLogController.maxPlaysPerBatch).map { _ in Self.play(contentId: soundId) }

            try await post(Self.batch(plays), on: app) { res in
                #expect(res.status == .payloadTooLarge)
            }
        }
    }

    @Test func `Accepts a full batch above Vapor's default body limit`() async throws {
        try await withSeededApp { app in
            let plays = (0..<PlayLogController.maxPlaysPerBatch).map { _ in Self.play(contentId: soundId) }

            try await post(Self.batch(plays), on: app) { res in
                #expect(res.status == .ok)
                let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
                #expect(body.stored == PlayLogController.maxPlaysPerBatch)
            }
        }
    }

    @Test func `Rejects missing install id`() async throws {
        try await withSeededApp { app in
            let batch = PlayLogController.PlayLogBatch(installId: "", appVersion: "13.2", plays: [Self.play(contentId: soundId)])

            try await post(batch, on: app) { res in
                #expect(res.status == .badRequest)
            }
        }
    }

    // MARK: - Helpers

    private func post(
        _ batch: PlayLogController.PlayLogBatch,
        on app: Application,
        afterResponse: @escaping (TestingHTTPResponse) async throws -> Void
    ) async throws {
        try await app.testing().test(.POST, "api/v4/play-logs", beforeRequest: { req async throws in
            try req.content.encode(batch)
        }, afterResponse: afterResponse)
    }

    private static let dateTime = "2026-10-06T12:34:56.789Z"

    private static func play(contentId: UUID, isAutoplay: Bool = false) -> PlayLogController.Play {
        PlayLogController.Play(
            id: UUID().uuidString,
            contentId: contentId.uuidString,
            dateTime: dateTime,
            isAutoplay: isAutoplay
        )
    }

    private static func batch(_ plays: [PlayLogController.Play]) -> PlayLogController.PlayLogBatch {
        PlayLogController.PlayLogBatch(installId: "install-1", appVersion: "13.2", plays: plays)
    }

    private static func makeContent(id: UUID, type: ContentType) -> MedoContent {
        let content = MedoContent()
        content.id = id
        content.title = "Test"
        content.authorId = ""
        content.description = ""
        content.fileId = ""
        content.creationDate = dateTime
        content.duration = 2
        content.isOffensive = false
        content.musicGenre = nil
        content.contentType = type
        content.isHidden = false
        return content
    }
}
