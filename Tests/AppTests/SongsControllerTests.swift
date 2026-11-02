@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct SongsControllerTests {

    private func createContent(
        title: String = "Música",
        contentType: ContentType = .song,
        musicGenre: String? = "AAAAAAAA-0000-0000-0000-000000000001",
        isHidden: Bool = false,
        on app: Application
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
        return try #require(content.id)
    }

    @Test func `All songs returns the song JSON`() async throws {
        try await withTestApp { app in
            let id = try await createContent(on: app)

            try await app.testing().test(.GET, "api/v3/all-songs", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(list.count == 1)
                let json = try #require(list.first)
                #expect(Set(json.keys) == ["id", "title", "description", "genreId", "duration", "filename", "dateAdded", "isOffensive", "isFromServer"])
                #expect(json["id"] as? String == id.uuidString)
                #expect(json["title"] as? String == "Música")
                #expect(json["description"] as? String == "Descrição")
                #expect(json["genreId"] as? String == "AAAAAAAA-0000-0000-0000-000000000001")
                #expect(json["duration"] as? Double == 123.5)
                #expect(json["filename"] as? String == "arquivo-Música.mp3")
                #expect(json["dateAdded"] as? String == "2026-10-01T12:34:56Z")
                #expect(json["isOffensive"] as? Bool == true)
                #expect(json["isFromServer"] as? Bool == true)
            })
        }
    }

    @Test func `All songs leaves out sounds and hidden songs`() async throws {
        try await withTestApp { app in
            let visible = try await createContent(title: "Visível", on: app)
            _ = try await createContent(title: "Escondida", isHidden: true, on: app)
            _ = try await createContent(title: "Som", contentType: .sound, on: app)

            try await app.testing().test(.GET, "api/v3/all-songs", afterResponse: { res async throws in
                #expect(try res.content.decode([Song].self).map(\.id) == [visible.uuidString])
            })
        }
    }

    @Test func `Song without a genre gets the undefined genre`() async throws {
        try await withTestApp { app in
            let id = try await createContent(musicGenre: nil, on: app)

            try await app.testing().test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async throws in
                #expect(try res.content.decode(Song.self).genreId == "16B61F20-5D24-429F-8751-55F62DBB8DA8")
            })
        }
    }

    @Test func `Get song returns the song`() async throws {
        try await withTestApp { app in
            let id = try await createContent(on: app)

            try await app.testing().test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let song = try res.content.decode(Song.self)
                #expect(song.id == id.uuidString)
                #expect(song.filename == "arquivo-Música.mp3")
            })
        }
    }

    @Test func `Get song is not found for hidden songs`() async throws {
        try await withTestApp { app in
            let id = try await createContent(isHidden: true, on: app)

            try await app.testing().test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    /// The query doesn't filter by content type, so a sound's id comes back shaped as a
    /// song. Pinned so changing it is a deliberate decision.
    @Test func `Get song also returns sounds shaped as songs`() async throws {
        try await withTestApp { app in
            let id = try await createContent(title: "Som", contentType: .sound, on: app)

            try await app.testing().test(.GET, "api/v3/song/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(Song.self).title == "Som")
            })
        }
    }

    @Test func `Get song is not found for an unknown id`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/song/\(UUID().uuidString)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Get song with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/song/not-a-uuid", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test func `Delete song with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v3/song/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }
}
