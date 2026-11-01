@testable import App
import XCTVapor
import Fluent
import Foundation

final class SongsControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func createContent(
        title: String = "Música",
        contentType: ContentType = .song,
        musicGenre: String? = "AAAAAAAA-0000-0000-0000-000000000001",
        isHidden: Bool = false
    ) async throws -> UUID {
        let content = MedoContent()
        content.title = title
        content.authorId = ""
        content.description = "Descrição"
        content.fileId = "arquivo-\(title)"
        content.creationDate = "2026-10-01T12:34:56.789Z"
        content.duration = 123.5
        content.isOffensive = true
        content.musicGenre = musicGenre
        content.contentType = contentType
        content.isHidden = isHidden
        try await content.save(on: app.db)
        return try XCTUnwrap(content.id)
    }

    func testAllSongsReturnsTheSongJSON() async throws {
        let id = try await createContent()

        try await app.test(.GET, "api/v3/all-songs", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
            XCTAssertEqual(list.count, 1)
            let json = try XCTUnwrap(list.first)
            XCTAssertEqual(Set(json.keys), ["id", "title", "description", "genreId", "duration", "filename", "dateAdded", "isOffensive", "isFromServer"])
            XCTAssertEqual(json["id"] as? String, id.uuidString)
            XCTAssertEqual(json["title"] as? String, "Música")
            XCTAssertEqual(json["description"] as? String, "Descrição")
            XCTAssertEqual(json["genreId"] as? String, "AAAAAAAA-0000-0000-0000-000000000001")
            XCTAssertEqual(json["duration"] as? Double, 123.5)
            XCTAssertEqual(json["filename"] as? String, "arquivo-Música.mp3")
            XCTAssertEqual(json["dateAdded"] as? String, "2026-10-01T12:34:56Z")
            XCTAssertEqual(json["isOffensive"] as? Bool, true)
            XCTAssertEqual(json["isFromServer"] as? Bool, true)
        })
    }

    func testAllSongsLeavesOutSoundsAndHiddenSongs() async throws {
        let visible = try await createContent(title: "Visível")
        _ = try await createContent(title: "Escondida", isHidden: true)
        _ = try await createContent(title: "Som", contentType: .sound)

        try await app.test(.GET, "api/v3/all-songs", afterResponse: { res async throws in
            XCTAssertEqual(try res.content.decode([Song].self).map(\.id), [visible.uuidString])
        })
    }

    func testSongWithoutAGenreGetsTheUndefinedGenre() async throws {
        let id = try await createContent(musicGenre: nil)

        try await app.test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(try res.content.decode(Song.self).genreId, "16B61F20-5D24-429F-8751-55F62DBB8DA8")
        })
    }

    func testGetSongReturnsTheSong() async throws {
        let id = try await createContent()

        try await app.test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let song = try res.content.decode(Song.self)
            XCTAssertEqual(song.id, id.uuidString)
            XCTAssertEqual(song.filename, "arquivo-Música.mp3")
        })
    }

    func testGetSongIsNotFoundForHiddenSongs() async throws {
        let id = try await createContent(isHidden: true)

        try await app.test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    /// The query doesn't filter by content type, so a sound's id comes back shaped as a
    /// song. Pinned so changing it is a deliberate decision.
    func testGetSongAlsoReturnsSoundsShapedAsSongs() async throws {
        let id = try await createContent(title: "Som", contentType: .sound)

        try await app.test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(Song.self).title, "Som")
        })
    }

    func testGetSongIsNotFoundForAnUnknownId() async throws {
        try await app.test(.GET, "api/v3/song/\(UUID().uuidString)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    /// Arguably should be 400; pinned so changing it is a deliberate decision.
    func testGetSongWithAnInvalidIdIsAServerError() async throws {
        try await app.test(.GET, "api/v3/song/not-a-uuid", afterResponse: { res async in
            XCTAssertEqual(res.status, .internalServerError)
        })
    }
}
