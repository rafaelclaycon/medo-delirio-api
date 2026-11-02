@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct AuthorsControllerTests {

    private func createAuthor(
        name: String = "Fulano",
        isHidden: Bool? = false,
        externalLinks: String? = nil,
        featuredRank: Int? = nil,
        on app: Application
    ) async throws -> UUID {
        let author = Author()
        author.name = name
        author.photo = "https://example.com/fulano.jpg"
        author.description = nil
        author.externalLinks = externalLinks
        author.isHidden = isHidden
        author.featuredRank = featuredRank
        try await author.save(on: app.db)
        return try #require(author.id)
    }

    @Test func `Featured rank is nil for a new author`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(on: app)

            try await app.testing().test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(Author.self).featuredRank == nil)
            })
        }
    }

    @Test func `Update author sets the featured rank and returns it`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(on: app)
            let update = Author()
            update.id = id
            update.name = "Fulano"
            update.photo = "https://example.com/fulano.jpg"
            update.description = nil
            update.externalLinks = nil
            update.isHidden = false
            update.featuredRank = 2

            try await app.testing().test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                try req.content.encode(update)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            try await app.testing().test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
                #expect(try res.content.decode(Author.self).featuredRank == 2)
            })
            try await app.testing().test(.GET, "api/v3/all-authors", afterResponse: { res async throws in
                #expect(try res.content.decode([Author].self).first?.featuredRank == 2)
            })
        }
    }

    @Test func `Update author can take the author out of the row`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(featuredRank: 1, on: app)
            let update = Author()
            update.id = id
            update.name = "Fulano"
            update.photo = nil
            update.description = nil
            update.externalLinks = nil
            update.isHidden = false
            update.featuredRank = 0

            try await app.testing().test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                try req.content.encode(update)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await Author.find(id, on: app.db)
            #expect(saved?.featuredRank == nil)
        }
    }

    /// A MedoHelper from before the field existed sends updates without it.
    @Test func `Update author without the field keeps the rank`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(featuredRank: 3, on: app)
            let body = """
            {"id": "\(id.uuidString)", "name": "Fulano Editado", "photo": null, "description": null, "externalLinks": null}
            """

            try await app.testing().test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await Author.find(id, on: app.db)
            #expect(saved?.name == "Fulano Editado")
            #expect(saved?.featuredRank == 3)
        }
    }

    // MARK: - Behaviour pinned before the async/await conversion

    @Test func `Get author returns the author JSON`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(externalLinks: #"[{"title":"Site"}]"#, featuredRank: 4, on: app)

            try await app.testing().test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let json = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
                #expect(Set(json.keys) == ["id", "name", "photo", "description", "isHidden", "externalLinks", "featuredRank"])
                #expect(json["id"] as? String == id.uuidString)
                #expect(json["name"] as? String == "Fulano")
                #expect(json["photo"] as? String == "https://example.com/fulano.jpg")
                #expect(json["description"] is NSNull)
                #expect(json["isHidden"] as? Bool == false)
                #expect(json["externalLinks"] as? String == #"[{"title":"Site"}]"#)
                #expect(json["featuredRank"] as? Int == 4)
            })
        }
    }

    @Test func `Get author finds hidden authors`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(isHidden: true, on: app)

            try await app.testing().test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(Author.self).isHidden == true)
            })
        }
    }

    @Test func `Get author is not found for an unknown id`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/author/\(UUID().uuidString)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Get author with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/author/not-a-uuid", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test func `All authors leaves out hidden authors`() async throws {
        try await withTestApp { app in
            let visible = try await createAuthor(name: "Visível", on: app)
            _ = try await createAuthor(name: "Escondido", isHidden: true, on: app)

            try await app.testing().test(.GET, "api/v3/all-authors", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([Author].self).map(\.id) == [visible])
            })
        }
    }

    @Test func `Author links only returns visible authors with links`() async throws {
        try await withTestApp { app in
            let withLinks = try await createAuthor(name: "Com links", externalLinks: "[]", on: app)
            _ = try await createAuthor(name: "Sem links", on: app)
            _ = try await createAuthor(name: "Escondido com links", isHidden: true, externalLinks: "[]", on: app)

            try await app.testing().test(.GET, "api/v4/author-links-first-open", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([Author].self).map(\.id) == [withLinks])
            })
        }
    }

    @Test func `Update author records a metadata updated event`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(on: app)
            let body = #"{"id": "\#(id.uuidString)", "name": "Fulano Editado", "photo": null, "description": "Bio", "externalLinks": "[]"}"#

            try await app.testing().test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await Author.find(id, on: app.db)
            #expect(saved?.name == "Fulano Editado")
            #expect(saved?.photo == nil)
            #expect(saved?.description == "Bio")
            #expect(saved?.externalLinks == "[]")

            let events = try await UpdateEvent.query(on: app.db).all()
            #expect(events.count == 1)
            #expect(events.first?.contentId == id.uuidString)
            #expect(events.first?.mediaType == .author)
            #expect(events.first?.eventType == .metadataUpdated)
            #expect(events.first?.visible == true)
        }
    }

    @Test func `Update author is not found for an unknown author`() async throws {
        try await withTestApp { app in
            let body = #"{"id": "\#(UUID().uuidString)", "name": "Ninguém"}"#

            try await app.testing().test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
            let eventCount = try await UpdateEvent.query(on: app.db).count()
            #expect(eventCount == 0)
        }
    }

    @Test func `Update author rejects a wrong password`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(on: app)
            let body = #"{"id": "\#(id.uuidString)", "name": "Hacker"}"#

            try await app.testing().test(.PUT, "api/v3/update-author/wrong", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
            let saved = try await Author.find(id, on: app.db)
            #expect(saved?.name == "Fulano")
        }
    }

    @Test func `Delete author hides it and records a deleted event`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(on: app)

            try await app.testing().test(.DELETE, "api/v3/author/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await Author.find(id, on: app.db)
            #expect(saved?.isHidden == true)

            let events = try await UpdateEvent.query(on: app.db).all()
            #expect(events.count == 1)
            #expect(events.first?.contentId == id.uuidString)
            #expect(events.first?.mediaType == .author)
            #expect(events.first?.eventType == .deleted)
            #expect(events.first?.visible == true)

            try await app.testing().test(.GET, "api/v3/all-authors", afterResponse: { res async throws in
                #expect(try res.content.decode([Author].self).count == 0)
            })
        }
    }

    /// The event keeps the id exactly as it appeared in the URL, unlike updates, which
    /// always record the uppercase `uuidString`.
    @Test func `Delete author records the id as written in the URL`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(on: app)
            let lowercased = id.uuidString.lowercased()

            try await app.testing().test(.DELETE, "api/v3/author/\(lowercased)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let event = try await UpdateEvent.query(on: app.db).first()
            #expect(event?.contentId == lowercased)
        }
    }

    @Test func `Delete author is not found for an unknown author`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v3/author/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Delete author rejects a wrong password`() async throws {
        try await withTestApp { app in
            let id = try await createAuthor(on: app)

            try await app.testing().test(.DELETE, "api/v3/author/\(id.uuidString)/wrong", afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
            let saved = try await Author.find(id, on: app.db)
            #expect(saved?.isHidden == false)
        }
    }

    @Test func `Delete author with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v3/author/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }
}
