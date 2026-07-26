@testable import App
import XCTVapor
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
