@testable import App
import XCTVapor
import Foundation

final class EpisodeHighlightControllerTests: XCTestCase {
    var app: Application!

    private let path = "api/v4/episode-highlight"
    private var protectedPath: String { "\(path)/\(TestEnvironment.testPassword)" }

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testWithNothingSet_returnsNotFound() async throws {
        try await app.test(.GET, path) { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testSetThenGet_returnsTheHighlight() async throws {
        let highlight = EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "Lula eleito")

        try await set(highlight) { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
        try await app.test(.GET, path) { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(EpisodeHighlight.self), highlight)
        }
    }

    func testMissingLabel_comesBackEmpty() async throws {
        try await app.test(.POST, protectedPath, beforeRequest: { req async throws in
            try req.content.encode(["episodeId": "ep-123", "style": "lulaWin"])
        }) { res async in
            XCTAssertEqual(res.status, .ok)
        }
        try await app.test(.GET, path) { res async throws in
            XCTAssertEqual(try res.content.decode(EpisodeHighlight.self).label, "")
        }
    }

    func testBlankLabel_isSavedEmpty() async throws {
        try await set(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "  ")) { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(EpisodeHighlight.self).label, "")
        }
    }

    func testLabelOverThirtyCharacters_isRejected() async throws {
        try await set(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: String(repeating: "a", count: 31))) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testWrongPassword_isForbidden() async throws {
        try await app.test(.POST, "\(path)/wrong", beforeRequest: { req async throws in
            try req.content.encode(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "Lula eleito"))
        }) { res async in
            XCTAssertEqual(res.status, .forbidden)
        }
    }

    func testUnknownStyle_isRejected() async throws {
        try await set(EpisodeHighlight(episodeId: "ep-123", style: "confetti", label: "Lula eleito")) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testEmptyEpisodeId_isRejected() async throws {
        try await set(EpisodeHighlight(episodeId: " ", style: "lulaWin", label: "Lula eleito")) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testDelete_takesTheHighlightOff() async throws {
        try await set(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "Lula eleito")) { res async in
            XCTAssertEqual(res.status, .ok)
        }
        try await app.test(.DELETE, protectedPath) { res async in
            XCTAssertEqual(res.status, .noContent)
        }
        try await app.test(.GET, path) { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    // MARK: - Helpers

    private func set(
        _ highlight: EpisodeHighlight,
        afterResponse: @escaping (TestingHTTPResponse) async throws -> Void
    ) async throws {
        try await app.test(.POST, protectedPath, beforeRequest: { req async throws in
            try req.content.encode(highlight)
        }, afterResponse: afterResponse)
    }
}
