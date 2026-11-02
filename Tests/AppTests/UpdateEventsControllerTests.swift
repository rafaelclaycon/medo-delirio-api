@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct UpdateEventsControllerTests {

    @discardableResult
    private func createEvent(
        contentId: String = UUID().uuidString,
        dateTime: String,
        mediaType: MediaType = .sound,
        eventType: EventType = .created,
        visible: Bool = true,
        on app: Application
    ) async throws -> UpdateEvent {
        let event = UpdateEvent(contentId: contentId, dateTime: dateTime, mediaType: mediaType, eventType: eventType, visible: visible)
        try await event.save(on: app.db)
        return event
    }

    private func createContent(contentType: ContentType = .sound, on app: Application) async throws -> MedoContent {
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

    private func jsonList(_ res: TestingHTTPResponse) throws -> [[String: Any]] {
        try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
    }

    // MARK: - update-events/:date

    @Test func `All returns every visible event as JSON`() async throws {
        try await withTestApp { app in
            let event = try await createEvent(contentId: "CONTENT-1", dateTime: "2026-10-01T10:00:00.000Z", mediaType: .song, eventType: .metadataUpdated, on: app)
            try await createEvent(dateTime: "2026-10-02T10:00:00.000Z", visible: false, on: app)

            try await app.testing().test(.GET, "api/v3/update-events/all", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let list = try self.jsonList(res)
                #expect(list.count == 1)
                let json = try #require(list.first)
                #expect(Set(json.keys) == ["id", "contentId", "dateTime", "mediaType", "eventType", "visible"])
                #expect(json["id"] as? String == event.id?.uuidString)
                #expect(json["contentId"] as? String == "CONTENT-1")
                #expect(json["dateTime"] as? String == "2026-10-01T10:00:00.000Z")
                #expect(json["mediaType"] as? Int == 2)
                #expect(json["eventType"] as? Int == 1)
                #expect(json["visible"] as? Bool == true)
            })
        }
    }

    @Test func `Date returns visible events strictly after it oldest first`() async throws {
        try await withTestApp { app in
            try await createEvent(contentId: "BEFORE", dateTime: "2026-10-01T09:59:59.999Z", on: app)
            try await createEvent(contentId: "EXACT", dateTime: "2026-10-01T10:00:00.000Z", on: app)
            let later = try await createEvent(contentId: "LATER", dateTime: "2026-10-03T10:00:00.000Z", mediaType: .author, eventType: .deleted, on: app)
            try await createEvent(contentId: "AFTER", dateTime: "2026-10-02T10:00:00.000Z", on: app)
            try await createEvent(contentId: "HIDDEN", dateTime: "2026-10-02T11:00:00.000Z", visible: false, on: app)

            try await app.testing().test(.GET, "api/v3/update-events/2026-10-01T10:00:00.000Z", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let list = try self.jsonList(res)
                #expect(list.map { $0["contentId"] as? String } == ["AFTER", "LATER"])

                let json = try #require(list.last)
                #expect(Set(json.keys) == ["id", "contentId", "dateTime", "mediaType", "eventType", "visible"])
                #expect(json["id"] as? String == later.id?.uuidString)
                #expect(json["dateTime"] as? String == "2026-10-03T10:00:00.000Z")
                #expect(json["mediaType"] as? Int == 1)
                #expect(json["eventType"] as? Int == 3)
                #expect(json["visible"] as? Bool == true)
            })
        }
    }

    @Test func `Date in any other format is a bad request`() async throws {
        try await withTestApp { app in
            for date in ["2026-10-01", "2026-10-01T10:00:00Z", "2026-10-01T10:00:00.000Z' OR '1'='1"] {
                let path = "api/v3/update-events/" + (date.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? date)
                try await app.testing().test(.GET, path, afterResponse: { res async in
                    #expect(res.status == .badRequest, "\(date)")
                })
            }
        }
    }

    // MARK: - update-events-for-display

    /// Removed in Nov 2026: unfinished, and no client called it.
    @Test func `For display is gone`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/update-events-for-display/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - change-update-visibility

    @Test func `Hiding an event keeps its date`() async throws {
        try await withTestApp { app in
            let event = try await createEvent(dateTime: "2026-10-01T10:00:00.000Z", on: app)
            let id = try #require(event.id)

            try await app.testing().test(.PUT, "api/v3/change-update-visibility/\(id.uuidString)/0/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await UpdateEvent.find(id, on: app.db)
            #expect(saved?.visible == false)
            #expect(saved?.dateTime == "2026-10-01T10:00:00.000Z")
        }
    }

    /// Showing an event moves it to now, so clients syncing from their last date pick it up.
    @Test func `Showing an event moves its date to now`() async throws {
        try await withTestApp { app in
            let event = try await createEvent(dateTime: "2026-10-01T10:00:00.000Z", visible: false, on: app)
            let id = try #require(event.id)
            let before = Date().iso8601withFractionalSeconds

            try await app.testing().test(.PUT, "api/v3/change-update-visibility/\(id.uuidString)/1/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await UpdateEvent.find(id, on: app.db)
            #expect(saved?.visible == true)
            #expect(try #require(saved?.dateTime) >= before)
        }
    }

    @Test func `Change visibility validates its parameters`() async throws {
        try await withTestApp { app in
            let event = try await createEvent(dateTime: "2026-10-01T10:00:00.000Z", on: app)
            let id = try #require(event.id).uuidString

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
                try await app.testing().test(.PUT, "api/v3/change-update-visibility/\(path)", afterResponse: { res async in
                    #expect(res.status == status, "\(path)")
                })
            }
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

    @Test func `Update content changes metadata but not file date or visibility`() async throws {
        try await withTestApp { app in
            let content = try await createContent(contentType: .sound, on: app)
            let id = try #require(content.id)

            try await app.testing().test(.PUT, "api/v3/update-content/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: self.updateContentBody(id: id, contentType: 1))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let found = try await MedoContent.find(id, on: app.db)
            let saved = try #require(found)
            #expect(saved.title == "Novo título")
            #expect(saved.authorId == "CCCCCCCC-0000-0000-0000-000000000002")
            #expect(saved.description == "Nova descrição")
            #expect(saved.duration == 9.5)
            #expect(saved.isOffensive == true)
            #expect(saved.musicGenre == "DDDDDDDD-0000-0000-0000-000000000003")
            #expect(saved.contentType == .song)
            #expect(saved.fileId == "arquivo-original")
            #expect(saved.creationDate == "2026-10-01T12:34:56.789Z")
            #expect(saved.isHidden == false)

            let events = try await UpdateEvent.query(on: app.db).all()
            #expect(events.count == 1)
            #expect(events.first?.contentId == id.uuidString)
            // Follows the content type sent in the request, here the new one.
            #expect(events.first?.mediaType == .song)
            #expect(events.first?.eventType == .metadataUpdated)
            #expect(events.first?.visible == true)
        }
    }

    @Test func `Update content is not found for unknown content`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.PUT, "api/v3/update-content/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: self.updateContentBody(id: UUID(), contentType: 0))
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
            let eventCount = try await UpdateEvent.query(on: app.db).count()
            #expect(eventCount == 0)
        }
    }

    @Test func `Update content rejects a wrong password`() async throws {
        try await withTestApp { app in
            let content = try await createContent(on: app)
            let id = try #require(content.id)

            try await app.testing().test(.PUT, "api/v3/update-content/wrong", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: self.updateContentBody(id: id, contentType: 0))
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
            let saved = try await MedoContent.find(id, on: app.db)
            #expect(saved?.title == "Original")
        }
    }

    // MARK: - update-content-file

    @Test func `Update content file records a file updated event`() async throws {
        try await withTestApp { app in
            for (type, mediaType) in [("sound", MediaType.sound), ("author", .author), ("song", .song), ("musicGenre", .musicGenre)] {
                try await app.testing().test(.POST, "api/v3/update-content-file/\(type)/ANY-ID-\(type)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                    #expect(res.status == .ok, "\(type)")
                })
                let event = try await UpdateEvent.query(on: app.db).filter(\.$contentId == "ANY-ID-\(type)").first()
                #expect(event?.mediaType == mediaType, "\(type)")
                #expect(event?.eventType == .fileUpdated, "\(type)")
                #expect(event?.visible == true, "\(type)")
            }
        }
    }

    @Test func `Update content file validates its parameters`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.POST, "api/v3/update-content-file/video/ANY-ID/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
            try await app.testing().test(.POST, "api/v3/update-content-file/sound/ANY-ID/wrong", afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
            let eventCount = try await UpdateEvent.query(on: app.db).count()
            #expect(eventCount == 0)
        }
    }
}
