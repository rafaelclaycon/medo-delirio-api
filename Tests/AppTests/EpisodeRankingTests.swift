@testable import App
import XCTVapor
import Fluent
import Foundation

final class EpisodeRankingTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)

        try await Episode(id: "ep-a", title: "Episódio A").create(on: app.db)
        try await Episode(id: "ep-b", title: "Episódio B").create(on: app.db)
        try await Episode(id: "ep-paren", title: "Bolsonaro (de novo)").create(on: app.db)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testRanksByListenersThenPlays() async throws {
        // A: 3 plays from 1 listener. B: 2 plays from 2 listeners. B ranks first.
        try await addPlays([
            ("install-1", "Episódio A", "2026-10-01T12:00:00.000Z"),
            ("install-1", "Episódio A", "2026-10-02T12:00:00.000Z"),
            ("install-1", "Episódio A", "2026-10-03T12:00:00.000Z"),
            ("install-1", "Episódio B", "2026-10-01T12:00:00.000Z"),
            ("install-2", "Episódio B", "2026-10-01T12:00:00.000Z")
        ])

        let items = try await get("api/v4/episode-play-count-stats-all-time")

        XCTAssertEqual(items.map(\.episodeId), ["ep-b", "ep-a"])
        XCTAssertEqual(items.map(\.uniqueListeners), [2, 1])
        XCTAssertEqual(items.map(\.playCount), [2, 3])
    }

    func testMatchesTitlesWithParentheses() async throws {
        try await addPlays([("install-1", "Bolsonaro (de novo)", "2026-10-01T12:00:00.000Z")])

        let items = try await get("api/v4/episode-play-count-stats-all-time")

        XCTAssertEqual(items.map(\.episodeId), ["ep-paren"])
        XCTAssertEqual(items.first?.episodeName, "Bolsonaro (de novo)")
    }

    func testFromLeavesOutEarlierPlays() async throws {
        try await addPlays([
            ("install-1", "Episódio A", "2026-09-30T12:00:00.000Z"),
            ("install-1", "Episódio B", "2026-10-02T12:00:00.000Z")
        ])

        let items = try await get("api/v4/episode-play-count-stats-from/2026-10-01")

        XCTAssertEqual(items.map(\.episodeId), ["ep-b"])
    }

    func testFromToIncludesAllOfTheLastDay() async throws {
        try await addPlays([
            ("install-1", "Episódio A", "2026-12-31T23:59:59.999Z"),
            ("install-1", "Episódio B", "2027-01-01T00:00:00.000Z")
        ])

        let items = try await get("api/v4/episode-play-count-stats-from-to/2026-01-01/2026-12-31")

        XCTAssertEqual(items.map(\.episodeId), ["ep-a"])
    }

    // MARK: - Helpers

    private func get(_ path: String) async throws -> [TopEpisodeItem] {
        var items: [TopEpisodeItem] = []
        try await app.test(.GET, path) { res async throws in
            XCTAssertEqual(res.status, .ok)
            items = try res.content.decode([TopEpisodeItem].self)
        }
        return items
    }

    private func addPlays(_ plays: [(installId: String, title: String, dateTime: String)]) async throws {
        for play in plays {
            try await UsageMetric(
                customInstallId: play.installId,
                originatingScreen: "EpisodePlayer",
                destinationScreen: "didPlayEpisode(\(play.title))",
                systemName: "iOS",
                isiOSAppOnMac: false,
                appVersion: "13.4",
                dateTime: play.dateTime,
                currentTimeZone: "BRT"
            ).create(on: app.db)
        }
    }
}
