@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct ShareRankingTests {

    /// A fresh app with this suite's fixtures already in place.
    private func withSeededApp(_ test: (Application) async throws -> Void) async throws {
        try await withTestApp { app in
            let author = Author()
            author.id = authorId
            author.name = "Autor"
            author.isHidden = false
            try await author.create(on: app.db)
            let genre = MusicGenre()
            genre.id = genreId
            genre.symbol = "🎸"
            genre.name = "Rock"
            genre.isHidden = false
            try await genre.create(on: app.db)
            try await Self.makeContent(id: soundA, type: .sound, authorId: authorId.uuidString).create(on: app.db)
            try await Self.makeContent(id: soundB, type: .sound, authorId: authorId.uuidString).create(on: app.db)
            try await Self.makeContent(id: song, type: .song, musicGenre: genreId.uuidString).create(on: app.db)
            try await addShare(soundA, type: .sound, count: 3, dateTime: "2026-03-10T12:00:00.000Z", on: app)
            try await addShare(soundB, type: .sound, count: 5, dateTime: "2025-06-10T12:00:00.000Z", on: app)
            try await addShare(song, type: .song, count: 2, dateTime: "2026-03-10T12:00:00.000Z", on: app)
            try await addShare(song, type: .song, count: 4, dateTime: "2025-06-10T12:00:00.000Z", on: app)
            try await test(app)
        }
    }

    private let authorId = UUID()
    private let genreId = UUID()
    private let soundA = UUID()
    private let soundB = UUID()
    private let song = UUID()

    @Test func `Sound from leaves out earlier shares`() async throws {
        try await withSeededApp { app in
            let items = try await getChart("api/v3/sound-share-count-stats-from/2026-01-01", on: app)

            #expect(items.map(\.contentId) == [soundA.uuidString])
            #expect(items.first?.shareCount == 3)
            #expect(items.first?.contentAuthorName == "Autor")
        }
    }

    @Test func `Sound from to keeps only that range`() async throws {
        try await withSeededApp { app in
            let items = try await getChart("api/v3/sound-share-count-stats-from-to/2025-01-01/2025-12-31", on: app)

            #expect(items.map(\.contentId) == [soundB.uuidString])
        }
    }

    @Test func `From to includes all of the last day`() async throws {
        try await withSeededApp { app in
            try await addShare(soundA, type: .sound, count: 1, dateTime: "2025-12-31T23:59:59.999Z", on: app)
            try await addShare(soundA, type: .sound, count: 10, dateTime: "2026-01-01T00:00:00.000Z", on: app)
            try await addShare(song, type: .song, count: 1, dateTime: "2025-12-31T18:00:00.000Z", on: app)

            let sounds = try await getChart("api/v3/sound-share-count-stats-from-to/2025-01-01/2025-12-31", on: app)
            #expect(sounds.map(\.contentId) == [soundB.uuidString, soundA.uuidString])
            #expect(sounds.map(\.shareCount) == [5, 1])

            let songs = try await getChart("api/v3/song-share-count-stats-from-to/2025-01-01/2025-12-31", on: app)
            #expect(songs.map(\.shareCount) == [5])
        }
    }

    @Test func `Song from and from to`() async throws {
        try await withSeededApp { app in
            let from = try await getChart("api/v3/song-share-count-stats-from/2026-01-01", on: app)
            #expect(from.map(\.shareCount) == [2])
            #expect(from.first?.contentAuthorName == "Rock")

            let range = try await getChart("api/v3/song-share-count-stats-from-to/2025-01-01/2025-12-31", on: app)
            #expect(range.map(\.shareCount) == [4])
        }
    }

    @Test func `Sound from V2`() async throws {
        try await withSeededApp { app in
            var stats: [ShareCountStat] = []
            try await app.testing().test(.GET, "api/v2/sound-share-count-stats-from/2026-01-01") { res async throws in
                #expect(res.status == .ok)
                stats = try res.content.decode([ShareCountStat].self)
            }

            #expect(stats.map(\.contentId) == [soundA.uuidString])
        }
    }

    @Test func `Stats for one sound`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.GET, "api/v3/sound-share-count-stats-for/\(soundB.uuidString)") { res async throws in
                #expect(res.status == .ok)
                let stats = try res.content.decode(ContentShareCountStats.self)
                #expect(stats.totalShareCount == 5)
                #expect(stats.topYear == "2025")
                #expect(stats.topMonth == "06")
            }
        }
    }

    @Test func `A date can't change the query`() async throws {
        try await withSeededApp { app in
            // Spliced into the SQL, this would read `> '2099-01-01' OR '1'='1'` and return everything.
            let date = "2099-01-01' OR '1'='1"
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!

            let items = try await getChart("api/v3/sound-share-count-stats-from/\(date)", on: app)

            #expect(items == [])
        }
    }

    // MARK: - Behaviour pinned before the async/await conversion

    @Test func `Sound all time V3 returns the chart JSON`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.GET, "api/v3/sound-share-count-stats-all-time") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(list.map { $0["contentId"] as? String } == [self.soundB.uuidString, self.soundA.uuidString])
                let json = try #require(list.first)
                #expect(Set(json.keys) == ["id", "rankNumber", "contentId", "contentName", "contentAuthorId", "contentAuthorName", "shareCount"])
                #expect(json["rankNumber"] as? String == "")
                #expect(json["contentName"] as? String == "Test")
                #expect(json["contentAuthorId"] as? String == self.authorId.uuidString)
                #expect(json["contentAuthorName"] as? String == "Autor")
                #expect(json["shareCount"] as? Int == 5)
            }
        }
    }

    @Test func `Sound all time V3 keeps the top ten`() async throws {
        try await withSeededApp { app in
            for index in 0..<11 {
                let id = UUID()
                try await Self.makeContent(id: id, type: .sound, authorId: authorId.uuidString).create(on: app.db)
                try await addShare(id, type: .sound, count: 100 + index, dateTime: "2026-03-10T12:00:00.000Z", on: app)
            }

            let items = try await getChart("api/v3/sound-share-count-stats-all-time", on: app)
            #expect(items.map(\.shareCount) == Array((101...110).reversed()))
        }
    }

    @Test func `Sound all time V2`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.GET, "api/v2/sound-share-count-stats-all-time") { res async throws in
                #expect(res.status == .ok)
                let stats = try res.content.decode([ShareCountStat].self)
                #expect(stats.map(\.contentId) == [self.soundB.uuidString, self.soundA.uuidString])
                #expect(stats.map(\.shareCount) == [5, 3])
                #expect(stats.map(\.installId) == ["", ""])
                #expect(stats.map(\.contentType) == [0, 0])
                // The query has no date column, so every row carries the time of the request.
                #expect(stats.allSatisfy { $0.dateTime?.isUTCDateString() == true })
            }
        }
    }

    @Test func `All sound share count stats V1 returns each sound share row`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.GET, "api/v1/all-sound-share-count-stats") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(Set(list.compactMap { $0["contentId"] as? String }) == [self.soundA.uuidString, self.soundB.uuidString])
                let json = try #require(list.first { $0["contentId"] as? String == self.soundB.uuidString })
                #expect(Set(json.keys) == ["id", "installId", "contentId", "contentType", "shareCount", "dateTime"])
                #expect(UUID(uuidString: json["id"] as? String ?? "") != nil)
                #expect(json["installId"] as? String == "install-1")
                #expect(json["contentType"] as? Int == 0)
                #expect(json["shareCount"] as? Int == 5)
                #expect(json["dateTime"] as? String == "2025-06-10T12:00:00.000Z")
            }
        }
    }

    @Test func `Stats for one sound counts the last week`() async throws {
        try await withSeededApp { app in
            try await addShare(soundB, type: .sound, count: 7, dateTime: Date().iso8601withFractionalSeconds, on: app)

            try await app.testing().test(.GET, "api/v3/sound-share-count-stats-for/\(soundB.uuidString)") { res async throws in
                #expect(res.status == .ok)
                let stats = try res.content.decode(ContentShareCountStats.self)
                #expect(stats.totalShareCount == 12)
                #expect(stats.lastWeekShareCount == 7)
            }
        }
    }

    @Test func `Stats for a sound without shares is not found`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.GET, "api/v3/sound-share-count-stats-for/\(UUID().uuidString)") { res async in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test func `Stats for a song is not found`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.GET, "api/v3/sound-share-count-stats-for/\(song.uuidString)") { res async in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test func `Song all time returns the chart JSON with the genre as author`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.GET, "api/v3/song-share-count-stats-all-time") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(list.count == 1)
                let json = try #require(list.first)
                #expect(Set(json.keys) == ["id", "rankNumber", "contentId", "contentName", "contentAuthorId", "contentAuthorName", "shareCount"])
                #expect(json["contentId"] as? String == self.song.uuidString)
                #expect(json["rankNumber"] as? String == "")
                #expect(json["contentName"] as? String == "Test")
                #expect(json["contentAuthorId"] as? String == "")
                #expect(json["contentAuthorName"] as? String == "Rock")
                #expect(json["shareCount"] as? Int == 6)
            }
        }
    }

    /// The charts join on MusicGenre, so a song without a known genre never shows up.
    @Test func `Song charts leave out songs without a genre`() async throws {
        try await withSeededApp { app in
            let orphan = UUID()
            try await Self.makeContent(id: orphan, type: .song, musicGenre: nil).create(on: app.db)
            try await addShare(orphan, type: .song, count: 50, dateTime: "2026-03-10T12:00:00.000Z", on: app)

            for path in [
                "api/v3/song-share-count-stats-all-time",
                "api/v3/song-share-count-stats-from/2026-01-01",
                "api/v3/song-share-count-stats-from-to/2026-01-01/2026-12-31",
            ] {
                let items = try await getChart(path, on: app)
                #expect(items.map(\.contentId) == [song.uuidString], "\(path)")
            }
        }
    }

    // MARK: - Helpers

    private func getChart(_ path: String, on app: Application) async throws -> [TopChartItem] {
        var items: [TopChartItem] = []
        try await app.testing().test(.GET, path) { res async throws in
            #expect(res.status == .ok)
            items = try res.content.decode([TopChartItem].self)
        }
        return items
    }

    private func addShare(_ contentId: UUID, type: ContentType, count: Int, dateTime: String, on app: Application) async throws {
        try await ShareCountStat(
            installId: "install-1",
            contentId: contentId.uuidString,
            contentType: type.rawValue,
            shareCount: count,
            dateTime: dateTime
        ).create(on: app.db)
    }

    private static func makeContent(
        id: UUID,
        type: ContentType,
        authorId: String = "",
        musicGenre: String? = nil
    ) -> MedoContent {
        let content = MedoContent()
        content.id = id
        content.title = "Test"
        content.authorId = authorId
        content.description = ""
        content.fileId = ""
        content.creationDate = "2025-01-01T00:00:00.000Z"
        content.duration = 2
        content.isOffensive = false
        content.musicGenre = musicGenre
        content.contentType = type
        content.isHidden = false
        return content
    }
}
