@testable import App
import Testing
import VaporTesting
import Foundation

struct EpisodeHighlightControllerTests {

    private let path = "api/v4/episode-highlight"
    private var protectedPath: String { "\(path)/\(TestEnvironment.testPassword)" }

    @Test func `With nothing set returns not found`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, path) { res async in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test func `Set then get returns the highlight`() async throws {
        try await withTestApp { app in
            let highlight = EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "Lula eleito")

            try await set(highlight, on: app) { res async throws in
                #expect(res.status == .ok)
            }
            try await app.testing().test(.GET, path) { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(EpisodeHighlight.self) == highlight)
            }
        }
    }

    @Test func `Missing label comes back empty`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.POST, protectedPath, beforeRequest: { req async throws in
                try req.content.encode(["episodeId": "ep-123", "style": "lulaWin"])
            }) { res async in
                #expect(res.status == .ok)
            }
            try await app.testing().test(.GET, path) { res async throws in
                #expect(try res.content.decode(EpisodeHighlight.self).label == "")
            }
        }
    }

    @Test func `Blank label is saved empty`() async throws {
        try await withTestApp { app in
            try await set(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "  "), on: app) { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(EpisodeHighlight.self).label == "")
            }
        }
    }

    @Test func `Label over thirty characters is rejected`() async throws {
        try await withTestApp { app in
            try await set(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: String(repeating: "a", count: 31)), on: app) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test func `Wrong password is forbidden`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.POST, "\(path)/wrong", beforeRequest: { req async throws in
                try req.content.encode(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "Lula eleito"))
            }) { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    @Test func `Unknown style is rejected`() async throws {
        try await withTestApp { app in
            try await set(EpisodeHighlight(episodeId: "ep-123", style: "confetti", label: "Lula eleito"), on: app) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test func `Empty episode id is rejected`() async throws {
        try await withTestApp { app in
            try await set(EpisodeHighlight(episodeId: " ", style: "lulaWin", label: "Lula eleito"), on: app) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test func `Delete takes the highlight off`() async throws {
        try await withTestApp { app in
            try await set(EpisodeHighlight(episodeId: "ep-123", style: "lulaWin", label: "Lula eleito"), on: app) { res async in
                #expect(res.status == .ok)
            }
            try await app.testing().test(.DELETE, protectedPath) { res async in
                #expect(res.status == .noContent)
            }
            try await app.testing().test(.GET, path) { res async in
                #expect(res.status == .notFound)
            }
        }
    }

    // MARK: - Helpers

    private func set(
        _ highlight: EpisodeHighlight,
        on app: Application,
        afterResponse: @escaping (TestingHTTPResponse) async throws -> Void
    ) async throws {
        try await app.testing().test(.POST, protectedPath, beforeRequest: { req async throws in
            try req.content.encode(highlight)
        }, afterResponse: afterResponse)
    }
}
