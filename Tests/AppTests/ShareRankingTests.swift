@testable import App
import XCTVapor
import Fluent
import Foundation

final class ShareRankingTests: XCTestCase {
    var app: Application!

    private let authorId = UUID()
    private let genreId = UUID()
    private let soundA = UUID()
    private let soundB = UUID()
    private let song = UUID()

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)

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

        try await addShare(soundA, type: .sound, count: 3, dateTime: "2026-03-10T12:00:00.000Z")
        try await addShare(soundB, type: .sound, count: 5, dateTime: "2025-06-10T12:00:00.000Z")
        try await addShare(song, type: .song, count: 2, dateTime: "2026-03-10T12:00:00.000Z")
        try await addShare(song, type: .song, count: 4, dateTime: "2025-06-10T12:00:00.000Z")
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testSoundFromLeavesOutEarlierShares() async throws {
        let items = try await getChart("api/v3/sound-share-count-stats-from/2026-01-01")

        XCTAssertEqual(items.map(\.contentId), [soundA.uuidString])
        XCTAssertEqual(items.first?.shareCount, 3)
        XCTAssertEqual(items.first?.contentAuthorName, "Autor")
    }

    func testSoundFromToKeepsOnlyThatRange() async throws {
        let items = try await getChart("api/v3/sound-share-count-stats-from-to/2025-01-01/2025-12-31")

        XCTAssertEqual(items.map(\.contentId), [soundB.uuidString])
    }

    func testFromToIncludesAllOfTheLastDay() async throws {
        try await addShare(soundA, type: .sound, count: 1, dateTime: "2025-12-31T23:59:59.999Z")
        try await addShare(soundA, type: .sound, count: 10, dateTime: "2026-01-01T00:00:00.000Z")
        try await addShare(song, type: .song, count: 1, dateTime: "2025-12-31T18:00:00.000Z")

        let sounds = try await getChart("api/v3/sound-share-count-stats-from-to/2025-01-01/2025-12-31")
        XCTAssertEqual(sounds.map(\.contentId), [soundB.uuidString, soundA.uuidString])
        XCTAssertEqual(sounds.map(\.shareCount), [5, 1])

        let songs = try await getChart("api/v3/song-share-count-stats-from-to/2025-01-01/2025-12-31")
        XCTAssertEqual(songs.map(\.shareCount), [5])
    }

    func testSongFromAndFromTo() async throws {
        let from = try await getChart("api/v3/song-share-count-stats-from/2026-01-01")
        XCTAssertEqual(from.map(\.shareCount), [2])
        XCTAssertEqual(from.first?.contentAuthorName, "Rock")

        let range = try await getChart("api/v3/song-share-count-stats-from-to/2025-01-01/2025-12-31")
        XCTAssertEqual(range.map(\.shareCount), [4])
    }

    func testSoundFromV2() async throws {
        var stats: [ShareCountStat] = []
        try await app.test(.GET, "api/v2/sound-share-count-stats-from/2026-01-01") { res async throws in
            XCTAssertEqual(res.status, .ok)
            stats = try res.content.decode([ShareCountStat].self)
        }

        XCTAssertEqual(stats.map(\.contentId), [soundA.uuidString])
    }

    func testStatsForOneSound() async throws {
        try await app.test(.GET, "api/v3/sound-share-count-stats-for/\(soundB.uuidString)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let stats = try res.content.decode(ContentShareCountStats.self)
            XCTAssertEqual(stats.totalShareCount, 5)
            XCTAssertEqual(stats.topYear, "2025")
            XCTAssertEqual(stats.topMonth, "06")
        }
    }

    func testADateCantChangeTheQuery() async throws {
        // Spliced into the SQL, this would read `> '2099-01-01' OR '1'='1'` and return everything.
        let date = "2099-01-01' OR '1'='1"
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!

        let items = try await getChart("api/v3/sound-share-count-stats-from/\(date)")

        XCTAssertEqual(items, [])
    }

    // MARK: - Helpers

    private func getChart(_ path: String) async throws -> [TopChartItem] {
        var items: [TopChartItem] = []
        try await app.test(.GET, path) { res async throws in
            XCTAssertEqual(res.status, .ok)
            items = try res.content.decode([TopChartItem].self)
        }
        return items
    }

    private func addShare(_ contentId: UUID, type: ContentType, count: Int, dateTime: String) async throws {
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
