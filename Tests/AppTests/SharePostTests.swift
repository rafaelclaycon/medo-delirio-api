@testable import App
import XCTVapor
import Fluent
import Foundation

final class SharePostTests: XCTestCase {
    var app: Application!

    private let sound = UUID()
    private let song = UUID()

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)

        for (id, type) in [(sound, ContentType.sound), (song, .song)] {
            let content = MedoContent()
            content.id = id
            content.title = "Test"
            content.authorId = ""
            content.description = ""
            content.fileId = ""
            content.creationDate = "2025-01-01T00:00:00.000Z"
            content.duration = 2
            content.isOffensive = false
            content.musicGenre = nil
            content.contentType = type
            content.isHidden = false
            try await content.create(on: app.db)
        }
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func postStat(contentId: String, contentType: Int, extra: String = #", "dateTime": "2026-11-01T10:00:00.000Z""#) async throws -> XCTHTTPResponse {
        let body = #"{"installId": "INSTALL-1", "contentId": "\#(contentId)", "contentType": \#(contentType), "shareCount": 1\#(extra)}"#
        var response: XCTHTTPResponse!
        try await app.test(.POST, "api/v1/share-count-stat", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            response = res
        })
        return response
    }

    // MARK: - share-count-stat

    func testPostingAShareSavesItAndReturnsIt() async throws {
        let res = try await postStat(contentId: sound.uuidString, contentType: 0)

        XCTAssertEqual(res.status, .ok)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["id", "installId", "contentId", "contentType", "shareCount", "dateTime"])
        XCTAssertNotNil(UUID(uuidString: json["id"] as? String ?? ""))
        XCTAssertEqual(json["installId"] as? String, "INSTALL-1")
        XCTAssertEqual(json["contentId"] as? String, sound.uuidString)
        XCTAssertEqual(json["contentType"] as? Int, 0)
        XCTAssertEqual(json["shareCount"] as? Int, 1)
        XCTAssertEqual(json["dateTime"] as? String, "2026-11-01T10:00:00.000Z")

        let saved = try await ShareCountStat.query(on: app.db).all()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.id?.uuidString, json["id"] as? String)
        XCTAssertEqual(saved.first?.dateTime, "2026-11-01T10:00:00.000Z")
    }

    /// The type the app reports only says whether it was a video share; the stored type
    /// follows what the content actually is.
    func testTheStoredContentTypeFollowsTheContent() async throws {
        let cases: [(content: UUID, reported: Int, stored: Int)] = [
            (sound, 0, 0), (sound, 1, 0), (sound, 2, 2), (sound, 3, 2),
            (song, 0, 1), (song, 1, 1), (song, 2, 3), (song, 3, 3),
        ]
        for (content, reported, stored) in cases {
            let res = try await postStat(contentId: content.uuidString, contentType: reported)
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(ShareCountStat.self).contentType, stored, "\(content == sound ? "sound" : "song") reported as \(reported)")
        }
        let savedTypes = try await ShareCountStat.query(on: app.db).all().map(\.contentType)
        XCTAssertEqual(savedTypes.sorted(), cases.map(\.stored).sorted())
    }

    func testAnUnknownContentTypeIsABadRequest() async throws {
        let res = try await postStat(contentId: sound.uuidString, contentType: 4)
        XCTAssertEqual(res.status, .badRequest)
        let count = try await ShareCountStat.query(on: app.db).count()
        XCTAssertEqual(count, 0)
    }

    func testAnInvalidContentIdIsABadRequest() async throws {
        let res = try await postStat(contentId: "not-a-uuid", contentType: 0)
        XCTAssertEqual(res.status, .badRequest)
    }

    func testAnUnknownContentIsNotFound() async throws {
        let res = try await postStat(contentId: UUID().uuidString, contentType: 0)
        XCTAssertEqual(res.status, .notFound)
        let count = try await ShareCountStat.query(on: app.db).count()
        XCTAssertEqual(count, 0)
    }

    /// A lowercase id still finds the content, but the stat keeps the id as sent.
    func testTheContentIdIsStoredAsSent() async throws {
        let res = try await postStat(contentId: sound.uuidString.lowercased(), contentType: 0)
        XCTAssertEqual(res.status, .ok)
        let saved = try await ShareCountStat.query(on: app.db).first()
        XCTAssertEqual(saved?.contentId, sound.uuidString.lowercased())
    }

    func testAShareWithoutADateIsSavedWithoutOne() async throws {
        let res = try await postStat(contentId: sound.uuidString, contentType: 0, extra: "")
        XCTAssertEqual(res.status, .ok)
        let saved = try await ShareCountStat.query(on: app.db).first()
        XCTAssertNotNil(saved)
        XCTAssertNil(saved?.dateTime)
    }

    // MARK: - shared-to-bundle-id

    func testPostingABundleIdLogSavesItAndReturnsIt() async throws {
        try await app.test(.POST, "api/v1/shared-to-bundle-id", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: #"{"bundleId": "net.whatsapp.WhatsApp.ShareExtension", "count": 3}"#)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["id", "bundleId", "count"])
            XCTAssertNotNil(UUID(uuidString: json["id"] as? String ?? ""))
            XCTAssertEqual(json["bundleId"] as? String, "net.whatsapp.WhatsApp.ShareExtension")
            XCTAssertEqual(json["count"] as? Int, 3)
        })

        let saved = try await ShareBundleIdLog.query(on: app.db).all()
        XCTAssertEqual(saved.map(\.bundleId), ["net.whatsapp.WhatsApp.ShareExtension"])
        XCTAssertEqual(saved.map(\.count), [3])
    }
}
