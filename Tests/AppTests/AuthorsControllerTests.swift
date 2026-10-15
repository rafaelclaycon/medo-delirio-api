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

    private func createAuthor(featuredRank: Int? = nil) async throws -> UUID {
        let author = Author()
        author.name = "Fulano"
        author.photo = "https://example.com/fulano.jpg"
        author.description = nil
        author.externalLinks = nil
        author.isHidden = false
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
}
