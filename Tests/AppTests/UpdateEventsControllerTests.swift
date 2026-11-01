@testable import App
import XCTVapor
import Fluent
import Foundation

final class UpdateEventsControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    @discardableResult
    private func createEvent(
        contentId: String = UUID().uuidString,
        dateTime: String,
        mediaType: MediaType = .sound,
        eventType: EventType = .created,
        visible: Bool = true
    ) async throws -> UpdateEvent {
        let event = UpdateEvent(contentId: contentId, dateTime: dateTime, mediaType: mediaType, eventType: eventType, visible: visible)
        try await event.save(on: app.db)
        return event
    }

    private func createContent(contentType: ContentType = .sound) async throws -> MedoContent {
        let content = MedoContent()
        content.title = "Original"
        content.authorId = "BBBBBBBB-0000-0000-0000-000000000001"
        content.description = "Descrição original"
        content.fileId = "arquivo-original"
        content.creationDate = "2026-10-01T12:34:56.789Z"
        content.duration = 2.5
        content.isOffensive = false
        content.musicGenre = nil
        content.contentType = contentType
        content.isHidden = false
        try await content.save(on: app.db)
        return content
    }

    private func jsonList(_ res: XCTHTTPResponse) throws -> [[String: Any]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
    }

    // MARK: - update-events/:date

    func testAllReturnsEveryVisibleEventAsJSON() async throws {
        let event = try await createEvent(contentId: "CONTENT-1", dateTime: "2026-10-01T10:00:00.000Z", mediaType: .song, eventType: .metadataUpdated)
        try await createEvent(dateTime: "2026-10-02T10:00:00.000Z", visible: false)

        try await app.test(.GET, "api/v3/update-events/all", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try self.jsonList(res)
            XCTAssertEqual(list.count, 1)
            let json = try XCTUnwrap(list.first)
            XCTAssertEqual(Set(json.keys), ["id", "contentId", "dateTime", "mediaType", "eventType", "visible"])
            XCTAssertEqual(json["id"] as? String, event.id?.uuidString)
            XCTAssertEqual(json["contentId"] as? String, "CONTENT-1")
            XCTAssertEqual(json["dateTime"] as? String, "2026-10-01T10:00:00.000Z")
            XCTAssertEqual(json["mediaType"] as? Int, 2)
            XCTAssertEqual(json["eventType"] as? Int, 1)
            XCTAssertEqual(json["visible"] as? Bool, true)
        })
    }

    func testDateReturnsVisibleEventsStrictlyAfterItOldestFirst() async throws {
        try await createEvent(contentId: "BEFORE", dateTime: "2026-10-01T09:59:59.999Z")
        try await createEvent(contentId: "EXACT", dateTime: "2026-10-01T10:00:00.000Z")
        let later = try await createEvent(contentId: "LATER", dateTime: "2026-10-03T10:00:00.000Z", mediaType: .author, eventType: .deleted)
        try await createEvent(contentId: "AFTER", dateTime: "2026-10-02T10:00:00.000Z")
        try await createEvent(contentId: "HIDDEN", dateTime: "2026-10-02T11:00:00.000Z", visible: false)

        try await app.test(.GET, "api/v3/update-events/2026-10-01T10:00:00.000Z", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try self.jsonList(res)
            XCTAssertEqual(list.map { $0["contentId"] as? String }, ["AFTER", "LATER"])

            let json = try XCTUnwrap(list.last)
            XCTAssertEqual(Set(json.keys), ["id", "contentId", "dateTime", "mediaType", "eventType", "visible"])
            XCTAssertEqual(json["id"] as? String, later.id?.uuidString)
            XCTAssertEqual(json["dateTime"] as? String, "2026-10-03T10:00:00.000Z")
            XCTAssertEqual(json["mediaType"] as? Int, 1)
            XCTAssertEqual(json["eventType"] as? Int, 3)
            XCTAssertEqual(json["visible"] as? Bool, true)
        })
    }

    func testDateInAnyOtherFormatIsABadRequest() async throws {
        for date in ["2026-10-01", "2026-10-01T10:00:00Z", "2026-10-01T10:00:00.000Z' OR '1'='1"] {
            let path = "api/v3/update-events/" + (date.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? date)
            try await app.test(.GET, path, afterResponse: { res async in
                XCTAssertEqual(res.status, .badRequest, date)
            })
        }
    }

    // MARK: - update-events-for-display

    /// The query joins MedoContent without an ON clause, so every event comes back once
    /// per content row (or once when there's no content at all), newest first. Pinned
    /// as it is; the handler is marked unfinished.
    func testForDisplayRepeatsEachVisibleEventOncePerContentRow() async throws {
        let older = try await createEvent(contentId: "OLDER", dateTime: "2026-10-01T10:00:00.000Z")
        let newer = try await createEvent(contentId: "NEWER", dateTime: "2026-10-02T10:00:00.000Z")
        try await createEvent(contentId: "HIDDEN", dateTime: "2026-10-03T10:00:00.000Z", visible: false)

        try await app.test(.GET, "api/v3/update-events-for-display/\(TestEnvironment.testPassword)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try self.jsonList(res)
            XCTAssertEqual(list.map { $0["contentId"] as? String }, ["NEWER", "OLDER"])
            XCTAssertEqual(list.map { $0["id"] as? String }, [newer.id?.uuidString, older.id?.uuidString])
        })

        _ = try await createContent()
        _ = try await createContent()

        try await app.test(.GET, "api/v3/update-events-for-display/\(TestEnvironment.testPassword)", afterResponse: { res async throws in
            XCTAssertEqual(try self.jsonList(res).map { $0["contentId"] as? String }, ["NEWER", "NEWER", "OLDER", "OLDER"])
        })
    }

    func testForDisplayRejectsAWrongPassword() async throws {
        try await app.test(.GET, "api/v3/update-events-for-display/wrong", afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
    }

    // MARK: - change-update-visibility

    func testHidingAnEventKeepsItsDate() async throws {
        let event = try await createEvent(dateTime: "2026-10-01T10:00:00.000Z")
        let id = try XCTUnwrap(event.id)

        try await app.test(.PUT, "api/v3/change-update-visibility/\(id.uuidString)/0/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await UpdateEvent.find(id, on: app.db)
        XCTAssertEqual(saved?.visible, false)
        XCTAssertEqual(saved?.dateTime, "2026-10-01T10:00:00.000Z")
    }

    /// Showing an event moves it to now, so clients syncing from their last date pick it up.
    func testShowingAnEventMovesItsDateToNow() async throws {
        let event = try await createEvent(dateTime: "2026-10-01T10:00:00.000Z", visible: false)
        let id = try XCTUnwrap(event.id)
        let before = Date().iso8601withFractionalSeconds

        try await app.test(.PUT, "api/v3/change-update-visibility/\(id.uuidString)/1/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await UpdateEvent.find(id, on: app.db)
        XCTAssertEqual(saved?.visible, true)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(saved?.dateTime), before)
    }

    func testChangeVisibilityValidatesItsParameters() async throws {
        let event = try await createEvent(dateTime: "2026-10-01T10:00:00.000Z")
        let id = try XCTUnwrap(event.id).uuidString

        let cases: [(path: String, status: HTTPStatus)] = [
            ("\(id)/0/wrong", .forbidden),
            ("\(id)/2/\(TestEnvironment.testPassword)", .badRequest),
            ("not-a-uuid/0/\(TestEnvironment.testPassword)", .badRequest),
            // The id is checked before the password.
            ("not-a-uuid/0/wrong", .badRequest),
            ("\(UUID().uuidString)/0/\(TestEnvironment.testPassword)", .notFound),
            ("\(id.lowercased())/0/\(TestEnvironment.testPassword)", .ok),
        ]
        for (path, status) in cases {
            try await app.test(.PUT, "api/v3/change-update-visibility/\(path)", afterResponse: { res async in
                XCTAssertEqual(res.status, status, path)
            })
        }
    }

    // MARK: - update-content

    private func updateContentBody(id: UUID, contentType: Int) -> String {
        """
        {"id": "\(id.uuidString)", "title": "Novo título", "authorId": "CCCCCCCC-0000-0000-0000-000000000002",
         "description": "Nova descrição", "fileId": "arquivo-novo", "creationDate": "2030-01-01T00:00:00.000Z",
         "duration": 9.5, "isOffensive": true, "musicGenre": "DDDDDDDD-0000-0000-0000-000000000003",
         "contentType": \(contentType), "isHidden": true}
        """
    }

    func testUpdateContentChangesMetadataButNotFileDateOrVisibility() async throws {
        let content = try await createContent(contentType: .sound)
        let id = try XCTUnwrap(content.id)

        try await app.test(.PUT, "api/v3/update-content/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: self.updateContentBody(id: id, contentType: 1))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let found = try await MedoContent.find(id, on: app.db)
        let saved = try XCTUnwrap(found)
        XCTAssertEqual(saved.title, "Novo título")
        XCTAssertEqual(saved.authorId, "CCCCCCCC-0000-0000-0000-000000000002")
        XCTAssertEqual(saved.description, "Nova descrição")
        XCTAssertEqual(saved.duration, 9.5)
        XCTAssertEqual(saved.isOffensive, true)
        XCTAssertEqual(saved.musicGenre, "DDDDDDDD-0000-0000-0000-000000000003")
        XCTAssertEqual(saved.contentType, .song)
        XCTAssertEqual(saved.fileId, "arquivo-original")
        XCTAssertEqual(saved.creationDate, "2026-10-01T12:34:56.789Z")
        XCTAssertEqual(saved.isHidden, false)

        let events = try await UpdateEvent.query(on: app.db).all()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.contentId, id.uuidString)
        // Follows the content type sent in the request, here the new one.
        XCTAssertEqual(events.first?.mediaType, .song)
        XCTAssertEqual(events.first?.eventType, .metadataUpdated)
        XCTAssertEqual(events.first?.visible, true)
    }

    func testUpdateContentIsNotFoundForUnknownContent() async throws {
        try await app.test(.PUT, "api/v3/update-content/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: self.updateContentBody(id: UUID(), contentType: 0))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
        let eventCount = try await UpdateEvent.query(on: app.db).count()
        XCTAssertEqual(eventCount, 0)
    }

    func testUpdateContentRejectsAWrongPassword() async throws {
        let content = try await createContent()
        let id = try XCTUnwrap(content.id)

        try await app.test(.PUT, "api/v3/update-content/wrong", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: self.updateContentBody(id: id, contentType: 0))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
        let saved = try await MedoContent.find(id, on: app.db)
        XCTAssertEqual(saved?.title, "Original")
    }

    // MARK: - update-content-file

    func testUpdateContentFileRecordsAFileUpdatedEvent() async throws {
        for (type, mediaType) in [("sound", MediaType.sound), ("author", .author), ("song", .song), ("musicGenre", .musicGenre)] {
            try await app.test(.POST, "api/v3/update-content-file/\(type)/ANY-ID-\(type)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                XCTAssertEqual(res.status, .ok, type)
            })
            let event = try await UpdateEvent.query(on: app.db).filter(\.$contentId == "ANY-ID-\(type)").first()
            XCTAssertEqual(event?.mediaType, mediaType, type)
            XCTAssertEqual(event?.eventType, .fileUpdated, type)
            XCTAssertEqual(event?.visible, true, type)
        }
    }

    func testUpdateContentFileValidatesItsParameters() async throws {
        try await app.test(.POST, "api/v3/update-content-file/video/ANY-ID/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
        try await app.test(.POST, "api/v3/update-content-file/sound/ANY-ID/wrong", afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
        let eventCount = try await UpdateEvent.query(on: app.db).count()
        XCTAssertEqual(eventCount, 0)
    }
}
