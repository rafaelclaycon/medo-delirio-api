@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct PlayRankingTests {

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
            try await Self.makeContent(id: soundA, title: "Sound A", type: .sound, authorId: authorId.uuidString).create(on: app.db)
            try await Self.makeContent(id: soundB, title: "Sound B", type: .sound, authorId: authorId.uuidString).create(on: app.db)
            try await Self.makeContent(id: hiddenSound, title: "Hidden", type: .sound, authorId: authorId.uuidString, isHidden: true).create(on: app.db)
            try await Self.makeContent(id: song, title: "Song", type: .song, musicGenre: genreId.uuidString).create(on: app.db)
            try await test(app)
        }
    }

    private let authorId = UUID()
    private let genreId = UUID()
    private let soundA = UUID()
    private let soundB = UUID()
    private let hiddenSound = UUID()
    private let song = UUID()

    @Test func `Ranks sounds by plays then listeners and leaves out songs`() async throws {
        try await withSeededApp { app in
            // A: 2 plays from 2 installs. B: 2 plays from 1 install. Same plays, so A ranks first.
            try await addPlays([
                (soundA, "install-1", Self.day("10-01")),
                (soundA, "install-2", Self.day("10-01")),
                (soundB, "install-1", Self.day("10-01")),
                (soundB, "install-1", Self.day("10-02")),
                (song, "install-1", Self.day("10-01"))
            ], on: app)

            let items = try await get("api/v4/sound-play-count-stats-all-time", on: app)

            #expect(items.map(\.contentId) == [soundA.uuidString, soundB.uuidString])
            #expect(items.map(\.playCount) == [2, 2])
            #expect(items.map(\.uniqueListeners) == [2, 1])
            #expect(items.first?.contentName == "Sound A")
            #expect(items.first?.contentAuthorId == authorId.uuidString)
            #expect(items.first?.contentAuthorName == "Autor")
        }
    }

    @Test func `Leaves out autoplay and hidden content`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                (soundA, "install-1", Self.day("10-01")),
                (hiddenSound, "install-1", Self.day("10-01"))
            ], on: app)
            try await addPlays([(soundB, "install-1", Self.day("10-01"))], isAutoplay: true, on: app)

            let items = try await get("api/v4/sound-play-count-stats-all-time", on: app)

            #expect(items.map(\.contentId) == [soundA.uuidString])
        }
    }

    @Test func `Song ranking shows the genre`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                (song, "install-1", Self.day("10-01")),
                (soundA, "install-1", Self.day("10-01"))
            ], on: app)

            let items = try await get("api/v4/song-play-count-stats-all-time", on: app)

            #expect(items.map(\.contentId) == [song.uuidString])
            #expect(items.first?.contentAuthorId == "")
            #expect(items.first?.contentAuthorName == "Rock")
        }
    }

    @Test func `From leaves out earlier plays`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                (soundA, "install-1", Self.day("09-30")),
                (soundB, "install-1", Self.day("10-02"))
            ], on: app)

            let items = try await get("api/v4/sound-play-count-stats-from/2026-10-01", on: app)

            #expect(items.map(\.contentId) == [soundB.uuidString])
        }
    }

    @Test func `From to includes all of the last day`() async throws {
        try await withSeededApp { app in
            try await addPlays([
                (soundA, "install-1", "2026-12-31T23:59:59.999Z"),
                (soundA, "install-2", "2027-01-01T00:00:00.000Z"),
                (soundB, "install-1", "2025-12-31T23:59:59.999Z")
            ], on: app)

            let items = try await get("api/v4/sound-play-count-stats-from-to/2026-01-01/2026-12-31", on: app)

            #expect(items.map(\.contentId) == [soundA.uuidString])
            #expect(items.first?.playCount == 1)
        }
    }

    @Test func `Returns the top ten`() async throws {
        try await withSeededApp { app in
            var plays: [(UUID, String, String)] = []
            for index in 0..<12 {
                let id = UUID()
                try await Self.makeContent(id: id, title: "Extra \(index)", type: .sound, authorId: authorId.uuidString).create(on: app.db)
                plays.append((id, "install-1", Self.day("10-01")))
            }
            try await addPlays(plays, on: app)

            let items = try await get("api/v4/sound-play-count-stats-all-time", on: app)

            #expect(items.count == 10)
        }
    }

    // MARK: - Helpers

    private func get(_ path: String, on app: Application) async throws -> [TopPlayedItem] {
        var items: [TopPlayedItem] = []
        try await app.testing().test(.GET, path) { res async throws in
            #expect(res.status == .ok)
            items = try res.content.decode([TopPlayedItem].self)
        }
        return items
    }

    private func addPlays(_ plays: [(contentId: UUID, installId: String, dateTime: String)], isAutoplay: Bool = false, on app: Application) async throws {
        for play in plays {
            let found = try await MedoContent.find(play.contentId, on: app.db)
            let content = try #require(found)
            try await PlayLog(
                id: UUID(),
                installId: play.installId,
                contentId: play.contentId.uuidString,
                contentType: content.contentType.rawValue,
                dateTime: play.dateTime,
                isAutoplay: isAutoplay,
                appVersion: "13.4"
            ).create(on: app.db)
        }
    }

    private static func day(_ monthDay: String) -> String {
        "2026-\(monthDay)T12:00:00.000Z"
    }

    private static func makeContent(
        id: UUID,
        title: String,
        type: ContentType,
        authorId: String = "",
        musicGenre: String? = nil,
        isHidden: Bool = false
    ) -> MedoContent {
        let content = MedoContent()
        content.id = id
        content.title = title
        content.authorId = authorId
        content.description = ""
        content.fileId = ""
        content.creationDate = "2026-10-01T00:00:00.000Z"
        content.duration = 2
        content.isOffensive = false
        content.musicGenre = musicGenre
        content.contentType = type
        content.isHidden = isHidden
        return content
    }
}
