@testable import App
import Testing
import VaporTesting
import Fluent
import FluentSQLiteDriver
import Foundation

struct WidgetSummaryTests {

    /// 15:00 UTC on 25 October 2026.
    private let now = Date(timeIntervalSince1970: 1_792_940_400)

    private func signal(_ installId: String, at dateTime: String, version: String = "13.6", on app: Application) async throws {
        try await StillAliveSignal(
            installId: installId, modelName: "iPhone17,1", systemName: "iOS", systemVersion: "26.0",
            isiOSAppOnMac: false, appVersion: version, currentTimeZone: "America/Sao_Paulo", dateTime: dateTime
        ).save(on: app.db)
    }

    private func metric(_ installId: String, _ originatingScreen: String, _ destinationScreen: String, at dateTime: String, on app: Application) async throws {
        try await UsageMetric(
            customInstallId: installId, originatingScreen: originatingScreen, destinationScreen: destinationScreen,
            systemName: "iOS", isiOSAppOnMac: false, appVersion: "13.6", dateTime: dateTime, currentTimeZone: "America/Sao_Paulo"
        ).save(on: app.db)
    }

    private func summary(on app: Application) async throws -> WidgetSummaryResponse {
        let sqlite = try #require(app.db as? SQLiteDatabase)
        return try await WidgetSummaryController.summary(on: sqlite, now: now)
    }

    @Test func `Windows are UTC days`() {
        let windows = WidgetSummaryController.Windows(now: now)
        #expect(windows.day == "2026-10-25")
        #expect(windows.todayStart == "2026-10-25T00:00:00.000Z")
        #expect(windows.yesterdayStart == "2026-10-24T00:00:00.000Z")
        #expect(windows.yesterdayUntilNow == "2026-10-24T15:00:00.000Z")
    }

    @Test func `Active users compare today with all of yesterday and yesterday until now`() async throws {
        try await withTestApp { app in
            try await signal("old", at: "2026-10-23T23:59:59.000Z", on: app)
            try await signal("a", at: "2026-10-24T09:00:00.000Z", on: app)
            try await signal("a", at: "2026-10-24T10:00:00.000Z", on: app)
            try await signal("b", at: "2026-10-24T20:00:00.000Z", on: app)
            try await signal("a", at: "2026-10-25T08:00:00.000Z", on: app)
            try await signal("c", at: "2026-10-25T14:00:00.000Z", on: app)
            try await signal("d", at: "2026-10-25T14:30:00.000Z", on: app)

            let users = try await summary(on: app).activeUsers
            #expect(users == .init(today: 3, yesterday: 2, yesterdayUntilNow: 1))
        }
    }

    @Test func `Chapter users count people not taps`() async throws {
        try await withTestApp { app in
            try await metric("a", "EpisodeDetail", "didTapChapter(184, Abertura)", at: "2026-10-25T10:00:00.000Z", on: app)
            try await metric("a", "NowPlaying", "didTapChapter(185, Notícias)", at: "2026-10-25T10:05:00.000Z", on: app)
            try await metric("b", "NowPlaying", "didTapChapter(184, Abertura)", at: "2026-10-25T11:00:00.000Z", on: app)
            try await metric("c", "EpisodeDetail", "didTapChapter(184, Abertura)", at: "2026-10-24T18:00:00.000Z", on: app)
            try await metric("d", "EpisodeDetail", "didTapPlay", at: "2026-10-25T11:00:00.000Z", on: app)
            try await metric("e", "Settings", "didTapChapter(184, Abertura)", at: "2026-10-25T11:00:00.000Z", on: app)

            let chapters = try await summary(on: app).chapterUsers
            #expect(chapters == .init(today: 2, yesterday: 1, yesterdayUntilNow: 0))
        }
    }

    @Test func `Game players started a game today and leave test devices out`() async throws {
        try await withTestApp { app in
            let testDevice = try #require(StatisticsController.testInstallIds.first)
            try await metric("a", "GameView", "didStartGame(whoseFace)", at: "2026-10-25T10:00:00.000Z", on: app)
            try await metric("a", "GameView", "didStartGame(whoseVoice)", at: "2026-10-25T10:10:00.000Z", on: app)
            try await metric("b", "GameView", "didStartGame(whoseFace)", at: "2026-10-25T12:00:00.000Z", on: app)
            try await metric("c", "GameView", "game_music_muted", at: "2026-10-25T12:00:00.000Z", on: app)
            try await metric("d", "GameView", "didStartGame(whoseFace)", at: "2026-10-24T22:00:00.000Z", on: app)
            try await metric(testDevice, "GameView", "didStartGame(whoseFace)", at: "2026-10-25T12:00:00.000Z", on: app)

            let players = try await summary(on: app).gamePlayers
            #expect(players == 2)
        }
    }

    @Test func `Top version is today's most used`() async throws {
        try await withTestApp { app in
            try await signal("a", at: "2026-10-25T10:00:00.000Z", version: "13.6", on: app)
            try await signal("b", at: "2026-10-25T10:00:00.000Z", version: "13.6", on: app)
            try await signal("c", at: "2026-10-25T10:00:00.000Z", version: "13.5", on: app)
            try await signal("d", at: "2026-10-24T10:00:00.000Z", version: "13.5", on: app)
            try await signal("e", at: "2026-10-24T10:00:00.000Z", version: "13.5", on: app)

            let topVersion = try await summary(on: app).topVersion
            #expect(topVersion == .init(appVersion: "13.6", uniqueUsers: 2, percentage: 66.7))
        }
    }

    @Test func `Empty day has no top version`() async throws {
        try await withTestApp { app in
            let response = try await summary(on: app)
            #expect(response.topVersion == nil)
            #expect(response.activeUsers == .init(today: 0, yesterday: 0, yesterdayUntilNow: 0))
        }
    }

    @Test func `Route needs the analytics password`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v4/widget-summary/wrong") { res async in
                #expect(res.status == .forbidden)
            }
            try await app.testing().test(.GET, "api/v4/widget-summary/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(throws: Never.self) {
                    try res.content.decode(WidgetSummaryResponse.self)
                }
            }
        }
    }
}
