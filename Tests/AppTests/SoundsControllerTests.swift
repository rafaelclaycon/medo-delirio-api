@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

private struct NewSoundPayload: Content {
    let title: String
    let authorId: String
    let description: String
    let fileId: String
    let creationDate: String
    let duration: Double
    let isOffensive: Bool
    let musicGenre: String?
    let contentType: Int
    let isHidden: Bool
}

struct SoundsControllerTests {

    @Test func `All sounds is empty on a fresh database`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let sounds = try res.content.decode([Sound].self)
                #expect(sounds.isEmpty)
            })
        }
    }

    @Test func `Create sound with wrong password is forbidden`() async throws {
        try await withTestApp { app in
            let payload = Self.samplePayload()
            try await app.testing().test(.POST, "api/v3/create-sound/wrong-password", beforeRequest: { req async throws in
                try req.content.encode(payload)
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
        }
    }

    @Test func `Create get and delete sound roundtrip`() async throws {
        try await withTestApp { app in
            let payload = Self.samplePayload()
            var createdId = ""

            try await app.testing().test(.POST, "api/v3/create-sound/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                try req.content.encode(payload)
            }, afterResponse: { res async throws in
                #expect(res.status == .created)
                let created = try JSONDecoder().decode(CreateContentResponse.self, from: Data(buffer: res.body))
                #expect(!created.contentId.isEmpty)
                createdId = created.contentId
            })

            try await app.testing().test(.GET, "api/v3/sound/\(createdId)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let sound = try res.content.decode(Sound.self)
                #expect(sound.id == createdId)
                #expect(sound.title == payload.title)
            })

            try await app.testing().test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Deletion is a soft-delete (isHidden = true), so the sound disappears
            // from the public listing but the row itself still exists.
            try await app.testing().test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
                let sounds = try res.content.decode([Sound].self)
                #expect(!(sounds.contains { $0.id == createdId }))
            })
        }
    }

    @Test func `Deleted sound is not served anymore`() async throws {
        try await withTestApp { app in
            let createdId = try await createSound(on: app)

            try await app.testing().test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // A client retrying the sound's old `created` event must not get it back.
            try await app.testing().test(.GET, "api/v3/sound/\(createdId)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Deleting a sound leaves only its deletion visible`() async throws {
        try await withTestApp { app in
            let createdId = try await createSound(on: app)
            let fetchedEvent = try await UpdateEvent.query(on: app.db).filter(\.$contentId == createdId).first()
            let createdEvent = try #require(fetchedEvent)
            createdEvent.visible = true
            try await createdEvent.save(on: app.db)

            try await app.testing().test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
            // Deleting again (to re-send the deletion) still works on hidden content.
            try await app.testing().test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            try await app.testing().test(.GET, "api/v3/update-events/all", afterResponse: { res async throws in
                let events = try res.content.decode([UpdateEvent].self).filter { $0.contentId == createdId }
                #expect(events.count == 1)
                #expect(events.first?.eventType == .deleted)
            })
        }
    }

    // MARK: - Behaviour pinned before the async/await conversion

    @Test func `All sounds returns the sound JSON`() async throws {
        try await withTestApp { app in
            let id = try await createContent(on: app)

            try await app.testing().test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(list.count == 1)
                let json = try #require(list.first)
                // authorName is always nil here, so the key is left out entirely.
                #expect(Set(json.keys) == ["id", "title", "authorId", "description", "filename", "dateAdded", "duration", "isOffensive", "isFromServer"])
                #expect(json["id"] as? String == id.uuidString)
                #expect(json["title"] as? String == "Som")
                #expect(json["authorId"] as? String == "BBBBBBBB-0000-0000-0000-000000000001")
                #expect(json["description"] as? String == "Descrição")
                #expect(json["filename"] as? String == "arquivo-Som.mp3")
                #expect(json["dateAdded"] as? String == "2026-10-01T12:34:56Z")
                #expect(json["duration"] as? Double == 2.5)
                #expect(json["isOffensive"] as? Bool == true)
                #expect(json["isFromServer"] as? Bool == true)
            })
        }
    }

    @Test func `All sounds leaves out songs and hidden sounds`() async throws {
        try await withTestApp { app in
            let visible = try await createContent(title: "Visível", on: app)
            _ = try await createContent(title: "Escondido", isHidden: true, on: app)
            _ = try await createContent(title: "Música", contentType: .song, on: app)

            try await app.testing().test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
                #expect(try res.content.decode([Sound].self).map(\.id) == [visible.uuidString])
            })
        }
    }

    /// The query doesn't filter by content type, so a song's id comes back shaped as a
    /// sound. Pinned so changing it is a deliberate decision.
    @Test func `Get sound also returns songs shaped as sounds`() async throws {
        try await withTestApp { app in
            let id = try await createContent(title: "Música", contentType: .song, on: app)

            try await app.testing().test(.GET, "api/v3/sound/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(Sound.self).title == "Música")
            })
        }
    }

    @Test func `Get sound is not found for an unknown id`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/sound/\(UUID().uuidString)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Get sound with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/sound/not-a-uuid", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test func `Delete sound with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v3/sound/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    private func createContent(
        title: String = "Som",
        contentType: ContentType = .sound,
        isHidden: Bool = false,
        on app: Application
    ) async throws -> UUID {
        let content = MedoContent()
        content.title = title
        content.authorId = "BBBBBBBB-0000-0000-0000-000000000001"
        content.description = "Descrição"
        content.fileId = "arquivo-\(title)"
        content.creationDate = "2026-10-01T12:34:56.789Z"
        content.duration = 2.5
        content.isOffensive = true
        content.musicGenre = nil
        content.contentType = contentType
        content.isHidden = isHidden
        try await content.save(on: app.db)
        return try #require(content.id)
    }

    private func createSound(on app: Application) async throws -> String {
        var createdId = ""
        try await app.testing().test(.POST, "api/v3/create-sound/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            try req.content.encode(Self.samplePayload())
        }, afterResponse: { res async throws in
            #expect(res.status == .created)
            createdId = try JSONDecoder().decode(CreateContentResponse.self, from: Data(buffer: res.body)).contentId
        })
        return createdId
    }

    private static func samplePayload() -> NewSoundPayload {
        NewSoundPayload(
            title: "Test Sound",
            authorId: UUID().uuidString,
            description: "A sound created by a test",
            fileId: "test-file-id",
            creationDate: Date().iso8601withFractionalSeconds,
            duration: 1.5,
            isOffensive: false,
            musicGenre: nil,
            contentType: 0,
            isHidden: false
        )
    }
}
