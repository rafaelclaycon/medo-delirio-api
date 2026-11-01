@testable import App
import XCTVapor
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

final class SoundsControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testAllSoundsIsEmptyOnAFreshDatabase() async throws {
        try await app.test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let sounds = try res.content.decode([Sound].self)
            XCTAssertTrue(sounds.isEmpty)
        })
    }

    func testCreateSoundWithWrongPasswordIsForbidden() async throws {
        let payload = Self.samplePayload()
        try await app.test(.POST, "api/v3/create-sound/wrong-password", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
    }

    func testCreateGetAndDeleteSoundRoundtrip() async throws {
        let payload = Self.samplePayload()
        var createdId = ""

        try await app.test(.POST, "api/v3/create-sound/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
            let created = try JSONDecoder().decode(CreateContentResponse.self, from: Data(buffer: res.body))
            XCTAssertFalse(created.contentId.isEmpty)
            createdId = created.contentId
        })

        try await app.test(.GET, "api/v3/sound/\(createdId)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let sound = try res.content.decode(Sound.self)
            XCTAssertEqual(sound.id, createdId)
            XCTAssertEqual(sound.title, payload.title)
        })

        try await app.test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        // Deletion is a soft-delete (isHidden = true), so the sound disappears
        // from the public listing but the row itself still exists.
        try await app.test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
            let sounds = try res.content.decode([Sound].self)
            XCTAssertFalse(sounds.contains { $0.id == createdId })
        })
    }

    func testDeletedSoundIsNotServedAnymore() async throws {
        let createdId = try await createSound()

        try await app.test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        // A client retrying the sound's old `created` event must not get it back.
        try await app.test(.GET, "api/v3/sound/\(createdId)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testDeletingASoundLeavesOnlyItsDeletionVisible() async throws {
        let createdId = try await createSound()
        let fetchedEvent = try await UpdateEvent.query(on: app.db).filter(\.$contentId == createdId).first()
        let createdEvent = try XCTUnwrap(fetchedEvent)
        createdEvent.visible = true
        try await createdEvent.save(on: app.db)

        try await app.test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })
        // Deleting again (to re-send the deletion) still works on hidden content.
        try await app.test(.DELETE, "api/v3/sound/\(createdId)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        try await app.test(.GET, "api/v3/update-events/all", afterResponse: { res async throws in
            let events = try res.content.decode([UpdateEvent].self).filter { $0.contentId == createdId }
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(events.first?.eventType, .deleted)
        })
    }

    // MARK: - Behaviour pinned before the async/await conversion

    func testAllSoundsReturnsTheSoundJSON() async throws {
        let id = try await createContent()

        try await app.test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
            XCTAssertEqual(list.count, 1)
            let json = try XCTUnwrap(list.first)
            // authorName is always nil here, so the key is left out entirely.
            XCTAssertEqual(Set(json.keys), ["id", "title", "authorId", "description", "filename", "dateAdded", "duration", "isOffensive", "isFromServer"])
            XCTAssertEqual(json["id"] as? String, id.uuidString)
            XCTAssertEqual(json["title"] as? String, "Som")
            XCTAssertEqual(json["authorId"] as? String, "BBBBBBBB-0000-0000-0000-000000000001")
            XCTAssertEqual(json["description"] as? String, "Descrição")
            XCTAssertEqual(json["filename"] as? String, "arquivo-Som.mp3")
            XCTAssertEqual(json["dateAdded"] as? String, "2026-10-01T12:34:56Z")
            XCTAssertEqual(json["duration"] as? Double, 2.5)
            XCTAssertEqual(json["isOffensive"] as? Bool, true)
            XCTAssertEqual(json["isFromServer"] as? Bool, true)
        })
    }

    func testAllSoundsLeavesOutSongsAndHiddenSounds() async throws {
        let visible = try await createContent(title: "Visível")
        _ = try await createContent(title: "Escondido", isHidden: true)
        _ = try await createContent(title: "Música", contentType: .song)

        try await app.test(.GET, "api/v3/all-sounds", afterResponse: { res async throws in
            XCTAssertEqual(try res.content.decode([Sound].self).map(\.id), [visible.uuidString])
        })
    }

    /// The query doesn't filter by content type, so a song's id comes back shaped as a
    /// sound. Pinned so changing it is a deliberate decision.
    func testGetSoundAlsoReturnsSongsShapedAsSounds() async throws {
        let id = try await createContent(title: "Música", contentType: .song)

        try await app.test(.GET, "api/v3/sound/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(Sound.self).title, "Música")
        })
    }

    func testGetSoundIsNotFoundForAnUnknownId() async throws {
        try await app.test(.GET, "api/v3/sound/\(UUID().uuidString)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    /// Arguably should be 400; pinned so changing it is a deliberate decision.
    func testGetSoundWithAnInvalidIdIsAServerError() async throws {
        try await app.test(.GET, "api/v3/sound/not-a-uuid", afterResponse: { res async in
            XCTAssertEqual(res.status, .internalServerError)
        })
    }

    private func createContent(
        title: String = "Som",
        contentType: ContentType = .sound,
        isHidden: Bool = false
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
        return try XCTUnwrap(content.id)
    }

    private func createSound() async throws -> String {
        var createdId = ""
        try await app.test(.POST, "api/v3/create-sound/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            try req.content.encode(Self.samplePayload())
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
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
