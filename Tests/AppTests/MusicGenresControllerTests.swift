@testable import App
import XCTVapor
import Fluent
import Foundation

final class MusicGenresControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func createGenre(name: String = "Forró", isHidden: Bool = false) async throws -> UUID {
        let genre = MusicGenre()
        genre.symbol = "🪗"
        genre.name = name
        genre.isHidden = isHidden
        try await genre.save(on: app.db)
        return try XCTUnwrap(genre.id)
    }

    func testGetMusicGenreReturnsTheGenreJSON() async throws {
        let id = try await createGenre()

        try await app.test(.GET, "api/v3/music-genre/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["id", "symbol", "name", "isHidden"])
            XCTAssertEqual(json["id"] as? String, id.uuidString)
            XCTAssertEqual(json["symbol"] as? String, "🪗")
            XCTAssertEqual(json["name"] as? String, "Forró")
            XCTAssertEqual(json["isHidden"] as? Bool, false)
        })
    }

    func testGetMusicGenreFindsHiddenGenres() async throws {
        let id = try await createGenre(isHidden: true)

        try await app.test(.GET, "api/v3/music-genre/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(MusicGenre.self).isHidden, true)
        })
    }

    func testGetMusicGenreIsNotFoundForAnUnknownId() async throws {
        try await app.test(.GET, "api/v3/music-genre/\(UUID().uuidString)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    /// Arguably should be 400; pinned so changing it is a deliberate decision.
    func testGetMusicGenreWithAnInvalidIdIsAServerError() async throws {
        try await app.test(.GET, "api/v3/music-genre/not-a-uuid", afterResponse: { res async in
            XCTAssertEqual(res.status, .internalServerError)
        })
    }

    func testAllMusicGenresLeavesOutHiddenGenres() async throws {
        let visible = try await createGenre(name: "Forró")
        _ = try await createGenre(name: "Axé", isHidden: true)

        try await app.test(.GET, "api/v3/all-music-genres", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([MusicGenre].self).map(\.id), [visible])
        })
    }

    func testDeleteMusicGenreHidesItAndRecordsADeletedEvent() async throws {
        let id = try await createGenre()

        try await app.test(.DELETE, "api/v3/music-genre/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await MusicGenre.find(id, on: app.db)
        XCTAssertEqual(saved?.isHidden, true)

        let events = try await UpdateEvent.query(on: app.db).all()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.contentId, id.uuidString)
        XCTAssertEqual(events.first?.mediaType, .musicGenre)
        XCTAssertEqual(events.first?.eventType, .deleted)
        XCTAssertEqual(events.first?.visible, true)
    }

    /// The event keeps the id exactly as it appeared in the URL.
    func testDeleteMusicGenreRecordsTheIdAsWrittenInTheURL() async throws {
        let id = try await createGenre()
        let lowercased = id.uuidString.lowercased()

        try await app.test(.DELETE, "api/v3/music-genre/\(lowercased)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let event = try await UpdateEvent.query(on: app.db).first()
        XCTAssertEqual(event?.contentId, lowercased)
    }

    func testDeleteMusicGenreIsNotFoundForAnUnknownGenre() async throws {
        try await app.test(.DELETE, "api/v3/music-genre/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
        let eventCount = try await UpdateEvent.query(on: app.db).count()
        XCTAssertEqual(eventCount, 0)
    }

    func testDeleteMusicGenreRejectsAWrongPassword() async throws {
        let id = try await createGenre()

        try await app.test(.DELETE, "api/v3/music-genre/\(id.uuidString)/wrong", afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
        let saved = try await MusicGenre.find(id, on: app.db)
        XCTAssertEqual(saved?.isHidden, false)
    }

    func testDeleteMusicGenreWithAnInvalidIdIsAServerError() async throws {
        try await app.test(.DELETE, "api/v3/music-genre/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .internalServerError)
        })
    }
}
