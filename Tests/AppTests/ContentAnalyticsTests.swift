@testable import App
import XCTVapor
import Fluent
import Foundation

final class ContentAnalyticsTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func metric(_ destination: String, from origin: String = "EpisodesTab", install: String = "install", at dateTime: String) async throws {
        try await UsageMetric(
            customInstallId: install, originatingScreen: origin, destinationScreen: destination,
            systemName: "iOS", isiOSAppOnMac: false, appVersion: "13.8",
            dateTime: dateTime, currentTimeZone: "America/Sao_Paulo"
        ).save(on: app.db)
    }

    private func daysAgo(_ days: Double) -> String {
        Date().addingTimeInterval(-days * 86_400).iso8601withFractionalSeconds
    }

    /// The UTC calendar day `days` ago, as `yyyy-MM-dd`.
    private func utcDay(_ days: Int = 0) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date().addingTimeInterval(-Double(days) * 86_400))
    }

    /// Just after midnight UTC, `days` ago: always inside both the daily series and the 30-day window.
    private func startOf(_ days: Int) -> String {
        "\(utcDay(days))T00:00:01.000Z"
    }

    private func jsonObject(_ res: XCTHTTPResponse) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
    }

    // MARK: - episode-analytics

    func testEpisodeAnalyticsCountsViewersPlayersAndBookmarkers() async throws {
        try await metric("didPlayEpisode(abc)", install: "a", at: startOf(0))
        try await metric("didPlayEpisode(def)", install: "a", at: startOf(0))
        try await metric("didPlayEpisode(abc)", install: "a", at: startOf(2))
        try await metric("didPlayEpisode(abc)", install: "b", at: startOf(2))
        try await metric("didAddBookmarkToEpisode(abc)", install: "b", at: startOf(2))
        try await metric("didAddBookmarkToEpisode(def)", install: "b", at: startOf(3))
        try await metric("didAddBookmarkToEpisode(abc)", install: "c", at: startOf(3))
        try await metric("didViewEpisodesScreen", install: "d", at: startOf(5))
        try await metric("didViewEpisode", install: "e", at: startOf(5))
        try await metric("didPlayEpisode(old)", install: "f", at: daysAgo(40))

        try await app.test(.GET, "api/v4/episode-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(Set(try self.jsonObject(res).keys), [
                "dailyUniqueUsers", "totalUniqueUsers", "totalViewers", "usersWhoPlayed",
                "usersWhoBookmarked", "averagePlaysPerUser", "averageBookmarksPerUser"
            ])
            let response = try res.content.decode(EpisodeAnalyticsResponse.self)
            XCTAssertEqual(response.totalViewers, 4)
            XCTAssertEqual(response.usersWhoPlayed, 2)
            XCTAssertEqual(response.totalUniqueUsers, 2)
            XCTAssertEqual(response.usersWhoBookmarked, 2)
            XCTAssertEqual(response.averagePlaysPerUser, 2.0)
            XCTAssertEqual(response.averageBookmarksPerUser, 1.5)

            // 30 UTC days, oldest first, counting distinct installs that played.
            XCTAssertEqual(response.dailyUniqueUsers.map(\.date), (0..<30).reversed().map { self.utcDay($0) })
            let nonZero = response.dailyUniqueUsers.filter { $0.activeUsers > 0 }
            XCTAssertEqual(nonZero.map { "\($0.date) \($0.activeUsers)" }, ["\(self.utcDay(2)) 2", "\(self.utcDay(0)) 1"])
        }
    }

    func testEpisodeAnalyticsIsZeroWithoutMetrics() async throws {
        try await app.test(.GET, "api/v4/episode-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(EpisodeAnalyticsResponse.self)
            XCTAssertEqual(response.dailyUniqueUsers.count, 30)
            XCTAssertTrue(response.dailyUniqueUsers.allSatisfy { $0.activeUsers == 0 })
            XCTAssertEqual(response.totalViewers, 0)
            XCTAssertEqual(response.averagePlaysPerUser, 0)
            XCTAssertEqual(response.averageBookmarksPerUser, 0)
        }
    }

    // MARK: - share-clip-analytics

    func testShareClipAnalyticsCountsTheFunnel() async throws {
        for _ in 0..<4 { try await metric("didTapShareClip", from: "NowPlaying", at: startOf(1)) }
        try await metric("didTapShareClip", from: "EpisodeDetail", at: startOf(1))
        try await metric("clip_shared(transcript=true)", from: "ShareClip", at: startOf(1))
        try await metric("clip_shared(transcript=true, length=30)", from: "ShareClip", at: startOf(0))
        try await metric("clip_shared(transcript=false)", from: "ShareClip", at: startOf(0))
        try await metric("clip_shared(transcript=true)", from: "Elsewhere", at: startOf(0))
        try await metric("clip_generation_failed(reason=timeout)", from: "ShareClip", at: startOf(0))
        try await metric("support_sheet_shown(trigger=share_clip)", from: "SupportPrompt", at: startOf(0))
        try await metric("support_sheet_shown(trigger=other)", from: "SupportPrompt", at: startOf(0))
        try await metric("dismissed", from: "ShareClipWhatsNew", at: startOf(0))
        try await metric("dismissed", from: "ShareClipWhatsNew", at: startOf(0))
        try await metric("clip_shared(transcript=true)", from: "ShareClip", at: daysAgo(40))

        try await app.test(.GET, "api/v4/share-clip-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(Set(try self.jsonObject(res).keys), [
                "dailySharesLast30Days", "tapCount", "sharedCount", "sharedWithTranscriptCount",
                "sharedWithoutTranscriptCount", "generationFailedCount", "supportPromptShownCount",
                "whatsNewDismissedCount", "conversionRate"
            ])
            let response = try res.content.decode(ShareClipAnalyticsResponse.self)
            XCTAssertEqual(response.tapCount, 4)
            XCTAssertEqual(response.sharedCount, 3)
            XCTAssertEqual(response.sharedWithTranscriptCount, 2)
            XCTAssertEqual(response.sharedWithoutTranscriptCount, 1)
            XCTAssertEqual(response.generationFailedCount, 1)
            XCTAssertEqual(response.supportPromptShownCount, 1)
            XCTAssertEqual(response.whatsNewDismissedCount, 2)
            XCTAssertEqual(response.conversionRate, 0.75)

            // Every share counts, not distinct installs.
            XCTAssertEqual(response.dailySharesLast30Days.map(\.date), (0..<30).reversed().map { self.utcDay($0) })
            let nonZero = response.dailySharesLast30Days.filter { $0.activeUsers > 0 }
            XCTAssertEqual(nonZero.map { "\($0.date) \($0.activeUsers)" }, ["\(self.utcDay(1)) 1", "\(self.utcDay(0)) 2"])
        }
    }

    func testShareClipAnalyticsIsZeroWithoutMetrics() async throws {
        try await app.test(.GET, "api/v4/share-clip-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(ShareClipAnalyticsResponse.self)
            XCTAssertEqual(response.dailySharesLast30Days.count, 30)
            XCTAssertEqual(response.tapCount, 0)
            XCTAssertEqual(response.sharedCount, 0)
            XCTAssertEqual(response.conversionRate, 0)
        }
    }

    // MARK: - chapters-usage-analytics

    func testChaptersUsageCountsTapsNavigationAndLoading() async throws {
        try await metric("didTapChapter(1, Abertura)", from: "EpisodeDetail", at: startOf(0))
        try await metric("didTapChapter(2, Notícias)", from: "EpisodeDetail", at: startOf(0))
        try await metric("didTapChapter(1, Abertura)", from: "NowPlaying", at: startOf(4))
        try await metric("didTapChapter(1, Abertura)", from: "Elsewhere", at: startOf(4))
        try await metric("chapter_previous", from: "NowPlaying", at: startOf(0))
        try await metric("chapter_next", from: "NowPlaying", at: startOf(0))
        try await metric("chapter_next", from: "NowPlaying", at: startOf(0))
        try await metric("chapter_next", from: "EpisodeDetail", at: startOf(0))
        try await metric("chapters_loaded(count=12)", from: "NowPlaying", at: startOf(0))
        try await metric("chapters_load_failed(abc, file_missing)", from: "NowPlaying", at: startOf(0))
        try await metric("chapters_load_failed(abc, decode_failed)", from: "NowPlaying", at: startOf(0))
        try await metric("chapters_load_failed(abc, decode_failed)", from: "NowPlaying", at: startOf(0))
        try await metric("chapters_load_failed(abc, no_entry)", from: "NowPlaying", at: startOf(0))
        try await metric("chapters_load_failed(abc, empty_list)", from: "NowPlaying", at: startOf(0))
        try await metric("chapters_load_failed(abc, other)", from: "NowPlaying", at: startOf(0))
        try await metric("chapters_hidden", from: "NowPlaying", at: startOf(0))
        try await metric("chapter_issue_reported", from: "NowPlaying", at: startOf(0))
        try await metric("chapter_issue_reported", from: "NowPlaying", at: daysAgo(40))

        try await app.test(.GET, "api/v4/chapters-usage-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(Set(try self.jsonObject(res).keys), [
                "dailyChapterTapsLast30Days", "tapCountEpisodeDetail", "tapCountNowPlaying",
                "previousCount", "nextCount", "loadedCount", "loadFailedCount",
                "loadFailedFileMissingCount", "loadFailedDecodeFailedCount", "loadFailedNoEntryCount",
                "loadFailedEmptyListCount", "hiddenCount", "issueReportedCount", "topChapters"
            ])
            let response = try res.content.decode(ChaptersUsageAnalyticsResponse.self)
            XCTAssertEqual(response.tapCountEpisodeDetail, 2)
            XCTAssertEqual(response.tapCountNowPlaying, 1)
            XCTAssertEqual(response.previousCount, 1)
            XCTAssertEqual(response.nextCount, 2)
            XCTAssertEqual(response.loadedCount, 1)
            XCTAssertEqual(response.loadFailedCount, 6)
            XCTAssertEqual(response.loadFailedFileMissingCount, 1)
            XCTAssertEqual(response.loadFailedDecodeFailedCount, 2)
            XCTAssertEqual(response.loadFailedNoEntryCount, 1)
            XCTAssertEqual(response.loadFailedEmptyListCount, 1)
            XCTAssertEqual(response.hiddenCount, 1)
            XCTAssertEqual(response.issueReportedCount, 1)

            XCTAssertEqual(response.dailyChapterTapsLast30Days.map(\.date), (0..<30).reversed().map { self.utcDay($0) })
            let nonZero = response.dailyChapterTapsLast30Days.filter { $0.tapCount > 0 }
            XCTAssertEqual(nonZero.map { "\($0.date) \($0.tapCount)" }, ["\(self.utcDay(4)) 1", "\(self.utcDay(0)) 2"])
        }
    }

    /// Like the rest of the response (and MedoHelper's "Últimos 30 dias" header), the
    /// ranking covers the last 30 days, and each chapter shows its latest title.
    func testTopChaptersCoverTheLast30DaysWithTheLatestTitle() async throws {
        try await metric("didTapChapter(7, Título antigo)", from: "EpisodeDetail", at: daysAgo(20))
        try await metric("didTapChapter(7, Título novo)", from: "NowPlaying", at: daysAgo(1))
        try await metric("didTapChapter(7, Título do meio)", from: "NowPlaying", at: daysAgo(10))
        try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(40))
        try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(41))
        try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(42))
        try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(43))
        try await metric("didTapChapter(3, Abertura, com vírgula)", from: "NowPlaying", at: daysAgo(1))
        try await metric("didTapChapter(3, Abertura, com vírgula)", from: "NowPlaying", at: daysAgo(2))
        try await metric("didTapChapter(9, Fim)", from: "NowPlaying", at: daysAgo(1))
        try await metric("didTapChapter(9, Fim)", from: "Elsewhere", at: daysAgo(1))
        try await metric("didTapChapter(sem título)", from: "NowPlaying", at: daysAgo(1))

        try await app.test(.GET, "api/v4/chapters-usage-analytics/\(TestEnvironment.testPassword)") { res async throws in
            let response = try res.content.decode(ChaptersUsageAnalyticsResponse.self)
            XCTAssertEqual(response.topChapters.map { "\($0.id) \($0.title) \($0.tapCount)" }, [
                "7 Título novo 3",
                "3 Abertura, com vírgula 2",
                "9 Fim 1"
            ])
        }
    }

    func testTopChaptersKeepsTheTop15() async throws {
        for id in 1...17 {
            for _ in 0..<id {
                try await metric("didTapChapter(\(id), Capítulo \(id))", from: "NowPlaying", at: daysAgo(1))
            }
        }

        try await app.test(.GET, "api/v4/chapters-usage-analytics/\(TestEnvironment.testPassword)") { res async throws in
            let response = try res.content.decode(ChaptersUsageAnalyticsResponse.self)
            XCTAssertEqual(response.topChapters.map(\.id), Array((3...17).reversed()))
        }
    }

    // MARK: - Passwords

    func testEveryRouteRejectsAWrongPassword() async throws {
        for path in ["api/v4/episode-analytics/wrong", "api/v4/share-clip-analytics/wrong", "api/v4/chapters-usage-analytics/wrong"] {
            try await app.test(.GET, path) { res async in
                XCTAssertEqual(res.status, .forbidden, path)
            }
        }
    }
}
