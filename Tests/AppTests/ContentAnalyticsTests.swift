@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct ContentAnalyticsTests {

    private func metric(_ destination: String, from origin: String = "EpisodesTab", install: String = "install", at dateTime: String, on app: Application) async throws {
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

    private func jsonObject(_ res: TestingHTTPResponse) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
    }

    // MARK: - episode-analytics

    @Test func `Episode analytics counts viewers players and bookmarkers`() async throws {
        try await withTestApp { app in
            try await metric("didPlayEpisode(abc)", install: "a", at: startOf(0), on: app)
            try await metric("didPlayEpisode(def)", install: "a", at: startOf(0), on: app)
            try await metric("didPlayEpisode(abc)", install: "a", at: startOf(2), on: app)
            try await metric("didPlayEpisode(abc)", install: "b", at: startOf(2), on: app)
            try await metric("didAddBookmarkToEpisode(abc)", install: "b", at: startOf(2), on: app)
            try await metric("didAddBookmarkToEpisode(def)", install: "b", at: startOf(3), on: app)
            try await metric("didAddBookmarkToEpisode(abc)", install: "c", at: startOf(3), on: app)
            try await metric("didViewEpisodesScreen", install: "d", at: startOf(5), on: app)
            try await metric("didViewEpisode", install: "e", at: startOf(5), on: app)
            try await metric("didPlayEpisode(old)", install: "f", at: daysAgo(40), on: app)

            try await app.testing().test(.GET, "api/v4/episode-analytics/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(Set(try self.jsonObject(res).keys) == [
                    "dailyUniqueUsers", "totalUniqueUsers", "totalViewers", "usersWhoPlayed",
                    "usersWhoBookmarked", "averagePlaysPerUser", "averageBookmarksPerUser"
                ])
                let response = try res.content.decode(EpisodeAnalyticsResponse.self)
                #expect(response.totalViewers == 4)
                #expect(response.usersWhoPlayed == 2)
                #expect(response.totalUniqueUsers == 2)
                #expect(response.usersWhoBookmarked == 2)
                #expect(response.averagePlaysPerUser == 2.0)
                #expect(response.averageBookmarksPerUser == 1.5)

                // 30 UTC days, oldest first, counting distinct installs that played.
                #expect(response.dailyUniqueUsers.map(\.date) == (0..<30).reversed().map { self.utcDay($0) })
                let nonZero = response.dailyUniqueUsers.filter { $0.activeUsers > 0 }
                #expect(nonZero.map { "\($0.date) \($0.activeUsers)" } == ["\(self.utcDay(2)) 2", "\(self.utcDay(0)) 1"])
            }
        }
    }

    @Test func `Episode analytics is zero without metrics`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v4/episode-analytics/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(EpisodeAnalyticsResponse.self)
                #expect(response.dailyUniqueUsers.count == 30)
                #expect(response.dailyUniqueUsers.allSatisfy { $0.activeUsers == 0 })
                #expect(response.totalViewers == 0)
                #expect(response.averagePlaysPerUser == 0)
                #expect(response.averageBookmarksPerUser == 0)
            }
        }
    }

    // MARK: - share-clip-analytics

    @Test func `Share clip analytics counts the funnel`() async throws {
        try await withTestApp { app in
            for _ in 0..<4 { try await metric("didTapShareClip", from: "NowPlaying", at: startOf(1), on: app) }
            try await metric("didTapShareClip", from: "EpisodeDetail", at: startOf(1), on: app)
            try await metric("clip_shared(transcript=true)", from: "ShareClip", at: startOf(1), on: app)
            try await metric("clip_shared(transcript=true, length=30)", from: "ShareClip", at: startOf(0), on: app)
            try await metric("clip_shared(transcript=false)", from: "ShareClip", at: startOf(0), on: app)
            try await metric("clip_shared(transcript=true)", from: "Elsewhere", at: startOf(0), on: app)
            try await metric("clip_generation_failed(reason=timeout)", from: "ShareClip", at: startOf(0), on: app)
            try await metric("support_sheet_shown(trigger=share_clip)", from: "SupportPrompt", at: startOf(0), on: app)
            try await metric("support_sheet_shown(trigger=other)", from: "SupportPrompt", at: startOf(0), on: app)
            try await metric("dismissed", from: "ShareClipWhatsNew", at: startOf(0), on: app)
            try await metric("dismissed", from: "ShareClipWhatsNew", at: startOf(0), on: app)
            try await metric("clip_shared(transcript=true)", from: "ShareClip", at: daysAgo(40), on: app)

            try await app.testing().test(.GET, "api/v4/share-clip-analytics/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(Set(try self.jsonObject(res).keys) == [
                    "dailySharesLast30Days", "tapCount", "sharedCount", "sharedWithTranscriptCount",
                    "sharedWithoutTranscriptCount", "generationFailedCount", "supportPromptShownCount",
                    "whatsNewDismissedCount", "conversionRate"
                ])
                let response = try res.content.decode(ShareClipAnalyticsResponse.self)
                #expect(response.tapCount == 4)
                #expect(response.sharedCount == 3)
                #expect(response.sharedWithTranscriptCount == 2)
                #expect(response.sharedWithoutTranscriptCount == 1)
                #expect(response.generationFailedCount == 1)
                #expect(response.supportPromptShownCount == 1)
                #expect(response.whatsNewDismissedCount == 2)
                #expect(response.conversionRate == 0.75)

                // Every share counts, not distinct installs.
                #expect(response.dailySharesLast30Days.map(\.date) == (0..<30).reversed().map { self.utcDay($0) })
                let nonZero = response.dailySharesLast30Days.filter { $0.activeUsers > 0 }
                #expect(nonZero.map { "\($0.date) \($0.activeUsers)" } == ["\(self.utcDay(1)) 1", "\(self.utcDay(0)) 2"])
            }
        }
    }

    @Test func `Share clip analytics is zero without metrics`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v4/share-clip-analytics/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(ShareClipAnalyticsResponse.self)
                #expect(response.dailySharesLast30Days.count == 30)
                #expect(response.tapCount == 0)
                #expect(response.sharedCount == 0)
                #expect(response.conversionRate == 0)
            }
        }
    }

    // MARK: - chapters-usage-analytics

    @Test func `Chapters usage counts taps navigation and loading`() async throws {
        try await withTestApp { app in
            try await metric("didTapChapter(1, Abertura)", from: "EpisodeDetail", at: startOf(0), on: app)
            try await metric("didTapChapter(2, Notícias)", from: "EpisodeDetail", at: startOf(0), on: app)
            try await metric("didTapChapter(1, Abertura)", from: "NowPlaying", at: startOf(4), on: app)
            try await metric("didTapChapter(1, Abertura)", from: "Elsewhere", at: startOf(4), on: app)
            try await metric("chapter_previous", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapter_next", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapter_next", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapter_next", from: "EpisodeDetail", at: startOf(0), on: app)
            try await metric("chapters_loaded(count=12)", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapters_load_failed(abc, file_missing)", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapters_load_failed(abc, decode_failed)", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapters_load_failed(abc, decode_failed)", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapters_load_failed(abc, no_entry)", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapters_load_failed(abc, empty_list)", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapters_load_failed(abc, other)", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapters_hidden", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapter_issue_reported", from: "NowPlaying", at: startOf(0), on: app)
            try await metric("chapter_issue_reported", from: "NowPlaying", at: daysAgo(40), on: app)

            try await app.testing().test(.GET, "api/v4/chapters-usage-analytics/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(Set(try self.jsonObject(res).keys) == [
                    "dailyChapterTapsLast30Days", "tapCountEpisodeDetail", "tapCountNowPlaying",
                    "previousCount", "nextCount", "loadedCount", "loadFailedCount",
                    "loadFailedFileMissingCount", "loadFailedDecodeFailedCount", "loadFailedNoEntryCount",
                    "loadFailedEmptyListCount", "hiddenCount", "issueReportedCount", "topChapters"
                ])
                let response = try res.content.decode(ChaptersUsageAnalyticsResponse.self)
                #expect(response.tapCountEpisodeDetail == 2)
                #expect(response.tapCountNowPlaying == 1)
                #expect(response.previousCount == 1)
                #expect(response.nextCount == 2)
                #expect(response.loadedCount == 1)
                #expect(response.loadFailedCount == 6)
                #expect(response.loadFailedFileMissingCount == 1)
                #expect(response.loadFailedDecodeFailedCount == 2)
                #expect(response.loadFailedNoEntryCount == 1)
                #expect(response.loadFailedEmptyListCount == 1)
                #expect(response.hiddenCount == 1)
                #expect(response.issueReportedCount == 1)

                #expect(response.dailyChapterTapsLast30Days.map(\.date) == (0..<30).reversed().map { self.utcDay($0) })
                let nonZero = response.dailyChapterTapsLast30Days.filter { $0.tapCount > 0 }
                #expect(nonZero.map { "\($0.date) \($0.tapCount)" } == ["\(self.utcDay(4)) 1", "\(self.utcDay(0)) 2"])
            }
        }
    }

    /// Like the rest of the response (and MedoHelper's "Últimos 30 dias" header), the
    /// ranking covers the last 30 days, and each chapter shows its latest title.
    @Test func `Top chapters cover the last 30 days with the latest title`() async throws {
        try await withTestApp { app in
            try await metric("didTapChapter(7, Título antigo)", from: "EpisodeDetail", at: daysAgo(20), on: app)
            try await metric("didTapChapter(7, Título novo)", from: "NowPlaying", at: daysAgo(1), on: app)
            try await metric("didTapChapter(7, Título do meio)", from: "NowPlaying", at: daysAgo(10), on: app)
            try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(40), on: app)
            try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(41), on: app)
            try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(42), on: app)
            try await metric("didTapChapter(4, Velho)", from: "NowPlaying", at: daysAgo(43), on: app)
            try await metric("didTapChapter(3, Abertura, com vírgula)", from: "NowPlaying", at: daysAgo(1), on: app)
            try await metric("didTapChapter(3, Abertura, com vírgula)", from: "NowPlaying", at: daysAgo(2), on: app)
            try await metric("didTapChapter(9, Fim)", from: "NowPlaying", at: daysAgo(1), on: app)
            try await metric("didTapChapter(9, Fim)", from: "Elsewhere", at: daysAgo(1), on: app)
            try await metric("didTapChapter(sem título)", from: "NowPlaying", at: daysAgo(1), on: app)

            try await app.testing().test(.GET, "api/v4/chapters-usage-analytics/\(TestEnvironment.testPassword)") { res async throws in
                let response = try res.content.decode(ChaptersUsageAnalyticsResponse.self)
                #expect(response.topChapters.map { "\($0.id) \($0.title) \($0.tapCount)" } == [
                    "7 Título novo 3",
                    "3 Abertura, com vírgula 2",
                    "9 Fim 1"
                ])
            }
        }
    }

    @Test func `Top chapters keeps the top 15`() async throws {
        try await withTestApp { app in
            for id in 1...17 {
                for _ in 0..<id {
                    try await metric("didTapChapter(\(id), Capítulo \(id))", from: "NowPlaying", at: daysAgo(1), on: app)
                }
            }

            try await app.testing().test(.GET, "api/v4/chapters-usage-analytics/\(TestEnvironment.testPassword)") { res async throws in
                let response = try res.content.decode(ChaptersUsageAnalyticsResponse.self)
                #expect(response.topChapters.map(\.id) == Array((3...17).reversed()))
            }
        }
    }

    // MARK: - Passwords

    @Test(arguments: ["api/v4/episode-analytics/wrong", "api/v4/share-clip-analytics/wrong", "api/v4/chapters-usage-analytics/wrong"])
    func `Every route rejects a wrong password`(path: String) async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, path) { res async in
                #expect(res.status == .forbidden)
            }
        }
    }
}
