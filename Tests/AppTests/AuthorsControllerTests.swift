@testable import App
import XCTVapor
import Fluent
import Foundation

final class AuthorsControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func createAuthor(
        name: String = "Fulano",
        isHidden: Bool? = false,
        externalLinks: String? = nil,
        featuredRank: Int? = nil
    ) async throws -> UUID {
        let author = Author()
        author.name = name
        author.photo = "https://example.com/fulano.jpg"
        author.description = nil
        author.externalLinks = externalLinks
        author.isHidden = isHidden
        author.featuredRank = featuredRank
        try await author.save(on: app.db)
        return try XCTUnwrap(author.id)
    }

    func testFeaturedRankIsNilForANewAuthor() async throws {
        let id = try await createAuthor()

        try await app.test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNil(try res.content.decode(Author.self).featuredRank)
        })
    }

    func testUpdateAuthorSetsTheFeaturedRankAndReturnsIt() async throws {
        let id = try await createAuthor()
        let update = Author()
        update.id = id
        update.name = "Fulano"
        update.photo = "https://example.com/fulano.jpg"
        update.description = nil
        update.externalLinks = nil
        update.isHidden = false
        update.featuredRank = 2

        try await app.test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            try req.content.encode(update)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        try await app.test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(try res.content.decode(Author.self).featuredRank, 2)
        })
        try await app.test(.GET, "api/v3/all-authors", afterResponse: { res async throws in
            XCTAssertEqual(try res.content.decode([Author].self).first?.featuredRank, 2)
        })
    }

    func testUpdateAuthorCanTakeTheAuthorOutOfTheRow() async throws {
        let id = try await createAuthor(featuredRank: 1)
        let update = Author()
        update.id = id
        update.name = "Fulano"
        update.photo = nil
        update.description = nil
        update.externalLinks = nil
        update.isHidden = false
        update.featuredRank = 0

        try await app.test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            try req.content.encode(update)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await Author.find(id, on: app.db)
        XCTAssertNil(saved?.featuredRank)
    }

    /// A MedoHelper from before the field existed sends updates without it.
    func testUpdateAuthorWithoutTheFieldKeepsTheRank() async throws {
        let id = try await createAuthor(featuredRank: 3)
        let body = """
        {"id": "\(id.uuidString)", "name": "Fulano Editado", "photo": null, "description": null, "externalLinks": null}
        """

        try await app.test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await Author.find(id, on: app.db)
        XCTAssertEqual(saved?.name, "Fulano Editado")
        XCTAssertEqual(saved?.featuredRank, 3)
    }

    // MARK: - Behaviour pinned before the async/await conversion

    func testGetAuthorReturnsTheAuthorJSON() async throws {
        let id = try await createAuthor(externalLinks: #"[{"title":"Site"}]"#, featuredRank: 4)

        try await app.test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["id", "name", "photo", "description", "isHidden", "externalLinks", "featuredRank"])
            XCTAssertEqual(json["id"] as? String, id.uuidString)
            XCTAssertEqual(json["name"] as? String, "Fulano")
            XCTAssertEqual(json["photo"] as? String, "https://example.com/fulano.jpg")
            XCTAssertTrue(json["description"] is NSNull)
            XCTAssertEqual(json["isHidden"] as? Bool, false)
            XCTAssertEqual(json["externalLinks"] as? String, #"[{"title":"Site"}]"#)
            XCTAssertEqual(json["featuredRank"] as? Int, 4)
        })
    }

    func testGetAuthorFindsHiddenAuthors() async throws {
        let id = try await createAuthor(isHidden: true)

        try await app.test(.GET, "api/v3/author/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(Author.self).isHidden, true)
        })
    }

    func testGetAuthorIsNotFoundForAnUnknownId() async throws {
        try await app.test(.GET, "api/v3/author/\(UUID().uuidString)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testGetAuthorWithAnInvalidIdIsABadRequest() async throws {
        try await app.test(.GET, "api/v3/author/not-a-uuid", afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testAllAuthorsLeavesOutHiddenAuthors() async throws {
        let visible = try await createAuthor(name: "Visível")
        _ = try await createAuthor(name: "Escondido", isHidden: true)

        try await app.test(.GET, "api/v3/all-authors", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([Author].self).map(\.id), [visible])
        })
    }

    func testAuthorLinksOnlyReturnsVisibleAuthorsWithLinks() async throws {
        let withLinks = try await createAuthor(name: "Com links", externalLinks: "[]")
        _ = try await createAuthor(name: "Sem links")
        _ = try await createAuthor(name: "Escondido com links", isHidden: true, externalLinks: "[]")

        try await app.test(.GET, "api/v4/author-links-first-open", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([Author].self).map(\.id), [withLinks])
        })
    }

    func testUpdateAuthorRecordsAMetadataUpdatedEvent() async throws {
        let id = try await createAuthor()
        let body = #"{"id": "\#(id.uuidString)", "name": "Fulano Editado", "photo": null, "description": "Bio", "externalLinks": "[]"}"#

        try await app.test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await Author.find(id, on: app.db)
        XCTAssertEqual(saved?.name, "Fulano Editado")
        XCTAssertNil(saved?.photo)
        XCTAssertEqual(saved?.description, "Bio")
        XCTAssertEqual(saved?.externalLinks, "[]")

        let events = try await UpdateEvent.query(on: app.db).all()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.contentId, id.uuidString)
        XCTAssertEqual(events.first?.mediaType, .author)
        XCTAssertEqual(events.first?.eventType, .metadataUpdated)
        XCTAssertEqual(events.first?.visible, true)
    }

    func testUpdateAuthorIsNotFoundForAnUnknownAuthor() async throws {
        let body = #"{"id": "\#(UUID().uuidString)", "name": "Ninguém"}"#

        try await app.test(.PUT, "api/v3/update-author/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
        let eventCount = try await UpdateEvent.query(on: app.db).count()
        XCTAssertEqual(eventCount, 0)
    }

    func testUpdateAuthorRejectsAWrongPassword() async throws {
        let id = try await createAuthor()
        let body = #"{"id": "\#(id.uuidString)", "name": "Hacker"}"#

        try await app.test(.PUT, "api/v3/update-author/wrong", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
        let saved = try await Author.find(id, on: app.db)
        XCTAssertEqual(saved?.name, "Fulano")
    }

    func testDeleteAuthorHidesItAndRecordsADeletedEvent() async throws {
        let id = try await createAuthor()

        try await app.test(.DELETE, "api/v3/author/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await Author.find(id, on: app.db)
        XCTAssertEqual(saved?.isHidden, true)

        let events = try await UpdateEvent.query(on: app.db).all()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.contentId, id.uuidString)
        XCTAssertEqual(events.first?.mediaType, .author)
        XCTAssertEqual(events.first?.eventType, .deleted)
        XCTAssertEqual(events.first?.visible, true)

        try await app.test(.GET, "api/v3/all-authors", afterResponse: { res async throws in
            XCTAssertEqual(try res.content.decode([Author].self).count, 0)
        })
    }

    /// The event keeps the id exactly as it appeared in the URL, unlike updates, which
    /// always record the uppercase `uuidString`.
    func testDeleteAuthorRecordsTheIdAsWrittenInTheURL() async throws {
        let id = try await createAuthor()
        let lowercased = id.uuidString.lowercased()

        try await app.test(.DELETE, "api/v3/author/\(lowercased)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let event = try await UpdateEvent.query(on: app.db).first()
        XCTAssertEqual(event?.contentId, lowercased)
    }

    func testDeleteAuthorIsNotFoundForAnUnknownAuthor() async throws {
        try await app.test(.DELETE, "api/v3/author/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testDeleteAuthorRejectsAWrongPassword() async throws {
        let id = try await createAuthor()

        try await app.test(.DELETE, "api/v3/author/\(id.uuidString)/wrong", afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
        let saved = try await Author.find(id, on: app.db)
        XCTAssertEqual(saved?.isHidden, false)
    }

    func testDeleteAuthorWithAnInvalidIdIsABadRequest() async throws {
        try await app.test(.DELETE, "api/v3/author/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }
}
