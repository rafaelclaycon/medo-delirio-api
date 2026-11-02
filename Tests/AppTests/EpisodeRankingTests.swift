@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct EpisodeRankingTests {

    /// A fresh app with this suite's fixtures already in place.
    private func withSeededApp(_ test: (Application) async throws -> Void) async throws {
        try await withTestApp { app in
            try await Episode(id: "ep-a", title: "Episódio A").create(on: app.db)
            try await Episode(id: "ep-b", title: "Episódio B").create(on: app.db)
            try await Episode(id: "ep-paren", title: "Bolsonaro (de novo)").create(on: app.db)
            try await test(app)
        }
    }

    @Test func `Ranks by listeners then plays`() async throws {
        try await withSeededApp { app in
            // A: 3 plays from 1 listener. B: 2 plays from 2 listeners. B ranks first.
            try await addPlays([
                ("install-1", "Episódio A", "2026-10-01T12:00:00.000Z"),
                ("install-1", "Episódio A", "2026-10-02T12:00:00.000Z"),
                ("install-1", "Episódio A", "2026-10-03T12:00:00.000Z"),
                ("install-1", "Episódio B", "2026-10-01T12:00:00.000Z"),
                ("install-2", "Episódio B", "2026-10-01T12:00:00.000Z")
            ], on: app)

            let items = try await get("api/v4/episode-play-count-stats-all-time", on: app)

            #expect(items.map(\.episodeId) == ["ep-b", "ep-a"])
            #expect(items.map(\.uniqueListeners) == [2, 1])
            #expect(items.map(\.playCount) == [2, 3])
        }
    }

    @Test func `Matches titles with parentheses`() async throws {
        try await withSeededApp { app in
            try await addPlays([("install-1", "Bolsonaro (de novo)", "2026-10-01T12:00:00.000Z")], on: app)

            let items = try await get("api/v4/episode-play-count-stats-all-time", on: app)

            #expect(items.map(\.episodeId) == ["ep-paren"])
            #expect(items.first?.episodeName == "Bolsonaro (de novo)")
        }
    }

    @Test func `From leaves out earlier plays`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                ("install-1", "Episódio A", "2026-09-30T12:00:00.000Z"),
                ("install-1", "Episódio B", "2026-10-02T12:00:00.000Z")
            ], on: app)

            let items = try await get("api/v4/episode-play-count-stats-from/2026-10-01", on: app)

            #expect(items.map(\.episodeId) == ["ep-b"])
        }
    }

    @Test func `From to includes all of the last day`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                ("install-1", "Episódio A", "2026-12-31T23:59:59.999Z"),
                ("install-1", "Episódio B", "2027-01-01T00:00:00.000Z")
            ], on: app)

            let items = try await get("api/v4/episode-play-count-stats-from-to/2026-01-01/2026-12-31", on: app)

            #expect(items.map(\.episodeId) == ["ep-a"])
        }
    }

    // MARK: - Behaviour pinned before the async/await conversion

    @Test func `Returns the episode chart JSON`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                ("install-1", "Episódio A", "2026-10-01T12:00:00.000Z"),
                ("install-2", "Episódio A", "2026-10-01T12:00:00.000Z")
            ], on: app)

            try await app.testing().test(.GET, "api/v4/episode-play-count-stats-all-time") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(list.count == 1)
                let json = try #require(list.first)
                #expect(Set(json.keys) == ["id", "rankNumber", "episodeId", "episodeName", "playCount", "uniqueListeners"])
                #expect(json["rankNumber"] as? String == "")
                #expect(json["episodeId"] as? String == "ep-a")
                #expect(json["episodeName"] as? String == "Episódio A")
                #expect(json["playCount"] as? Int == 2)
                #expect(json["uniqueListeners"] as? Int == 2)
            }
        }
    }

    @Test func `Leaves out plays of unknown episodes and other metrics`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                ("install-1", "Episódio A", "2026-10-01T12:00:00.000Z"),
                ("install-1", "Episódio que não existe", "2026-10-01T12:00:00.000Z")
            ], on: app)
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
                let items = try await get(path, on: app)
                #expect(items.map(\.episodeId) == ["ep-a"], "\(path)")
            }
        }
    }

    @Test func `Keeps the top ten`() async throws {
        try await withSeededApp { app in
            var plays: [(installId: String, title: String, dateTime: String)] = []
            for index in 1...11 {
                try await Episode(id: "ep-\(index)", title: "Episódio \(index)").create(on: app.db)
                for listener in 0..<index {
                    plays.append(("install-\(listener)", "Episódio \(index)", "2026-10-01T12:00:00.000Z"))
                }
            }
            try await addPlays(plays, on: app)

            let items = try await get("api/v4/episode-play-count-stats-all-time", on: app)
            #expect(items.map(\.uniqueListeners) == Array((2...11).reversed()))
        }
    }

    // MARK: - Helpers

    private func get(_ path: String, on app: Application) async throws -> [TopEpisodeItem] {
        var items: [TopEpisodeItem] = []
        try await app.testing().test(.GET, path) { res async throws in
            #expect(res.status == .ok)
            items = try res.content.decode([TopEpisodeItem].self)
        }
        return items
    }

    private func addPlays(_ plays: [(installId: String, title: String, dateTime: String)], on app: Application) async throws {
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
