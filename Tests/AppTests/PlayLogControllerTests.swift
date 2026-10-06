@testable import App
import XCTVapor
import Fluent
import Foundation

final class PlayLogControllerTests: XCTestCase {
    var app: Application!

    private let soundId = UUID()
    private let songId = UUID()

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)

        try await Self.makeContent(id: soundId, type: .sound).create(on: app.db)
        try await Self.makeContent(id: songId, type: .song).create(on: app.db)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testStoresPlaysAndTakesContentTypeFromTheCatalog() async throws {
        let batch = Self.batch([
            Self.play(contentId: soundId),
            Self.play(contentId: songId, isAutoplay: true)
        ])

        try await post(batch) { res in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
            XCTAssertEqual(body.received, 2)
            XCTAssertEqual(body.stored, 2)
        }

        let logs = try await PlayLog.query(on: app.db).all()
        XCTAssertEqual(logs.count, 2)
        let song = try XCTUnwrap(logs.first { $0.contentId == songId.uuidString })
        XCTAssertEqual(song.contentType, ContentType.song.rawValue)
        XCTAssertTrue(song.isAutoplay)
        XCTAssertEqual(song.installId, "install-1")
        XCTAssertEqual(song.appVersion, "13.2")
    }

    func testResendingABatchStoresItOnce() async throws {
        let batch = Self.batch([Self.play(contentId: soundId), Self.play(contentId: songId)])

        try await post(batch) { res in XCTAssertEqual(res.status, .ok) }
        try await post(batch) { res in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
            XCTAssertEqual(body.stored, 0)
        }

        let count = try await PlayLog.query(on: app.db).count()
        XCTAssertEqual(count, 2)
    }

    func testDropsBadRowsWithoutFailingTheBatch() async throws {
        let duplicate = Self.play(contentId: soundId)
        let batch = Self.batch([
            duplicate,
            duplicate,
            Self.play(contentId: UUID()),
            PlayLogController.Play(id: "not-a-uuid", contentId: soundId.uuidString, dateTime: Self.dateTime, isAutoplay: false),
            PlayLogController.Play(id: UUID().uuidString, contentId: soundId.uuidString, dateTime: "yesterday", isAutoplay: false),
            Self.play(contentId: songId)
        ])

        try await post(batch) { res in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
            XCTAssertEqual(body.received, 6)
            XCTAssertEqual(body.stored, 2)
        }
    }

    func testLowercaseContentIdIsStoredInCatalogCasing() async throws {
        let play = PlayLogController.Play(
            id: UUID().uuidString,
            contentId: soundId.uuidString.lowercased(),
            dateTime: Self.dateTime,
            isAutoplay: false
        )

        try await post(Self.batch([play])) { res in XCTAssertEqual(res.status, .ok) }

        let log = try await PlayLog.query(on: app.db).first()
        XCTAssertEqual(log?.contentId, soundId.uuidString)
    }

    func testRejectsOversizedBatch() async throws {
        let plays = (0...PlayLogController.maxPlaysPerBatch).map { _ in Self.play(contentId: soundId) }

        try await post(Self.batch(plays)) { res in
            XCTAssertEqual(res.status, .payloadTooLarge)
        }
    }

    func testAcceptsAFullBatchAboveVaporsDefaultBodyLimit() async throws {
        let plays = (0..<PlayLogController.maxPlaysPerBatch).map { _ in Self.play(contentId: soundId) }

        try await post(Self.batch(plays)) { res in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(PlayLogController.PlayLogBatchResponse.self)
            XCTAssertEqual(body.stored, PlayLogController.maxPlaysPerBatch)
        }
    }

    func testRejectsMissingInstallId() async throws {
        let batch = PlayLogController.PlayLogBatch(installId: "", appVersion: "13.2", plays: [Self.play(contentId: soundId)])

        try await post(batch) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    // MARK: - Helpers

    private func post(
        _ batch: PlayLogController.PlayLogBatch,
        afterResponse: @escaping (XCTHTTPResponse) async throws -> Void
    ) async throws {
        try await app.test(.POST, "api/v4/play-logs", beforeRequest: { req async throws in
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
