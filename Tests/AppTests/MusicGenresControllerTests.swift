@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct MusicGenresControllerTests {

    private func createGenre(name: String = "Forró", isHidden: Bool = false, on app: Application) async throws -> UUID {
        let genre = MusicGenre()
        genre.symbol = "🪗"
        genre.name = name
        genre.isHidden = isHidden
        try await genre.save(on: app.db)
        return try #require(genre.id)
    }

    @Test func `Get music genre returns the genre JSON`() async throws {
        try await withTestApp { app in
            let id = try await createGenre(on: app)

            try await app.testing().test(.GET, "api/v3/music-genre/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let json = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
                #expect(Set(json.keys) == ["id", "symbol", "name", "isHidden"])
                #expect(json["id"] as? String == id.uuidString)
                #expect(json["symbol"] as? String == "🪗")
                #expect(json["name"] as? String == "Forró")
                #expect(json["isHidden"] as? Bool == false)
            })
        }
    }

    @Test func `Get music genre finds hidden genres`() async throws {
        try await withTestApp { app in
            let id = try await createGenre(isHidden: true, on: app)

            try await app.testing().test(.GET, "api/v3/music-genre/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(MusicGenre.self).isHidden == true)
            })
        }
    }

    @Test func `Get music genre is not found for an unknown id`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/music-genre/\(UUID().uuidString)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Get music genre with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/music-genre/not-a-uuid", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test func `All music genres leaves out hidden genres`() async throws {
        try await withTestApp { app in
            let visible = try await createGenre(name: "Forró", on: app)
            _ = try await createGenre(name: "Axé", isHidden: true, on: app)

            try await app.testing().test(.GET, "api/v3/all-music-genres", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([MusicGenre].self).map(\.id) == [visible])
            })
        }
    }

    @Test func `Delete music genre hides it and records a deleted event`() async throws {
        try await withTestApp { app in
            let id = try await createGenre(on: app)

            try await app.testing().test(.DELETE, "api/v3/music-genre/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await MusicGenre.find(id, on: app.db)
            #expect(saved?.isHidden == true)

            let events = try await UpdateEvent.query(on: app.db).all()
            #expect(events.count == 1)
            #expect(events.first?.contentId == id.uuidString)
            #expect(events.first?.mediaType == .musicGenre)
            #expect(events.first?.eventType == .deleted)
            #expect(events.first?.visible == true)
        }
    }

    /// The event keeps the id exactly as it appeared in the URL.
    @Test func `Delete music genre records the id as written in the URL`() async throws {
        try await withTestApp { app in
            let id = try await createGenre(on: app)
            let lowercased = id.uuidString.lowercased()

            try await app.testing().test(.DELETE, "api/v3/music-genre/\(lowercased)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let event = try await UpdateEvent.query(on: app.db).first()
            #expect(event?.contentId == lowercased)
        }
    }

    @Test func `Delete music genre is not found for an unknown genre`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v3/music-genre/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
            let eventCount = try await UpdateEvent.query(on: app.db).count()
            #expect(eventCount == 0)
        }
    }

    @Test func `Delete music genre rejects a wrong password`() async throws {
        try await withTestApp { app in
            let id = try await createGenre(on: app)

            try await app.testing().test(.DELETE, "api/v3/music-genre/\(id.uuidString)/wrong", afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
            let saved = try await MusicGenre.find(id, on: app.db)
            #expect(saved?.isHidden == false)
        }
    }

    @Test func `Delete music genre with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v3/music-genre/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }
}
