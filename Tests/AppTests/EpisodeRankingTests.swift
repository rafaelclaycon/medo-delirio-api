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

    // MARK: - Behaviour pinned before the async/await conversion

    func testReturnsTheEpisodeChartJSON() async throws {
        try await addPlays([
            ("install-1", "Episódio A", "2026-10-01T12:00:00.000Z"),
            ("install-2", "Episódio A", "2026-10-01T12:00:00.000Z")
        ])

        try await app.test(.GET, "api/v4/episode-play-count-stats-all-time") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
            XCTAssertEqual(list.count, 1)
            let json = try XCTUnwrap(list.first)
            XCTAssertEqual(Set(json.keys), ["id", "rankNumber", "episodeId", "episodeName", "playCount", "uniqueListeners"])
            XCTAssertEqual(json["rankNumber"] as? String, "")
            XCTAssertEqual(json["episodeId"] as? String, "ep-a")
            XCTAssertEqual(json["episodeName"] as? String, "Episódio A")
            XCTAssertEqual(json["playCount"] as? Int, 2)
            XCTAssertEqual(json["uniqueListeners"] as? Int, 2)
        }
    }

    func testLeavesOutPlaysOfUnknownEpisodesAndOtherMetrics() async throws {
        try await addPlays([
            ("install-1", "Episódio A", "2026-10-01T12:00:00.000Z"),
            ("install-1", "Episódio que não existe", "2026-10-01T12:00:00.000Z")
        ])
        try await UsageMetric(
            customInstallId: "install-1",
            originatingScreen: "EpisodePlayer",
            destinationScreen: "didPauseEpisode(Episódio B)",
            systemName: "iOS",
            isiOSAppOnMac: false,
            appVersion: "13.4",
            dateTime: "2026-10-01T12:00:00.000Z",
            currentTimeZone: "BRT"
        ).create(on: app.db)

        for path in [
            "api/v4/episode-play-count-stats-all-time",
            "api/v4/episode-play-count-stats-from/2026-01-01",
            "api/v4/episode-play-count-stats-from-to/2026-01-01/2026-12-31",
        ] {
            let items = try await get(path)
            XCTAssertEqual(items.map(\.episodeId), ["ep-a"], path)
        }
    }

    func testKeepsTheTopTen() async throws {
        var plays: [(installId: String, title: String, dateTime: String)] = []
        for index in 1...11 {
            try await Episode(id: "ep-\(index)", title: "Episódio \(index)").create(on: app.db)
            for listener in 0..<index {
                plays.append(("install-\(listener)", "Episódio \(index)", "2026-10-01T12:00:00.000Z"))
            }
        }
        try await addPlays(plays)

        let items = try await get("api/v4/episode-play-count-stats-all-time")
        XCTAssertEqual(items.map(\.uniqueListeners), Array((2...11).reversed()))
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
