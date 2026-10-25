@testable import App
import XCTVapor
import Fluent
import FluentSQLiteDriver
import Foundation

final class WidgetSummaryTests: XCTestCase {

    var app: Application!

    /// 15:00 UTC on 25 October 2026.
    private let now = Date(timeIntervalSince1970: 1_792_940_400)

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func signal(_ installId: String, at dateTime: String, version: String = "13.6") async throws {
        try await StillAliveSignal(
            installId: installId, modelName: "iPhone17,1", systemName: "iOS", systemVersion: "26.0",
            isiOSAppOnMac: false, appVersion: version, currentTimeZone: "America/Sao_Paulo", dateTime: dateTime
        ).save(on: app.db)
    }

    private func metric(_ installId: String, _ originatingScreen: String, _ destinationScreen: String, at dateTime: String) async throws {
        try await UsageMetric(
            customInstallId: installId, originatingScreen: originatingScreen, destinationScreen: destinationScreen,
            systemName: "iOS", isiOSAppOnMac: false, appVersion: "13.6", dateTime: dateTime, currentTimeZone: "America/Sao_Paulo"
        ).save(on: app.db)
    }

    private func summary() async throws -> WidgetSummaryResponse {
        let sqlite = try XCTUnwrap(app.db as? SQLiteDatabase)
        return try await WidgetSummaryController.summary(on: sqlite, now: now)
    }

    func testWindowsAreUTCDays() {
        let windows = WidgetSummaryController.Windows(now: now)
        XCTAssertEqual(windows.day, "2026-10-25")
        XCTAssertEqual(windows.todayStart, "2026-10-25T00:00:00.000Z")
        XCTAssertEqual(windows.yesterdayStart, "2026-10-24T00:00:00.000Z")
        XCTAssertEqual(windows.yesterdayUntilNow, "2026-10-24T15:00:00.000Z")
    }

    func testActiveUsersCompareTodayWithAllOfYesterdayAndYesterdayUntilNow() async throws {
        try await signal("old", at: "2026-10-23T23:59:59.000Z")
        try await signal("a", at: "2026-10-24T09:00:00.000Z")
        try await signal("a", at: "2026-10-24T10:00:00.000Z")
        try await signal("b", at: "2026-10-24T20:00:00.000Z")
        try await signal("a", at: "2026-10-25T08:00:00.000Z")
        try await signal("c", at: "2026-10-25T14:00:00.000Z")
        try await signal("d", at: "2026-10-25T14:30:00.000Z")

        let users = try await summary().activeUsers
        XCTAssertEqual(users, .init(today: 3, yesterday: 2, yesterdayUntilNow: 1))
    }

    func testChapterUsersCountPeopleNotTaps() async throws {
        try await metric("a", "EpisodeDetail", "didTapChapter(184, Abertura)", at: "2026-10-25T10:00:00.000Z")
        try await metric("a", "NowPlaying", "didTapChapter(185, Notícias)", at: "2026-10-25T10:05:00.000Z")
        try await metric("b", "NowPlaying", "didTapChapter(184, Abertura)", at: "2026-10-25T11:00:00.000Z")
        try await metric("c", "EpisodeDetail", "didTapChapter(184, Abertura)", at: "2026-10-24T18:00:00.000Z")
        try await metric("d", "EpisodeDetail", "didTapPlay", at: "2026-10-25T11:00:00.000Z")
        try await metric("e", "Settings", "didTapChapter(184, Abertura)", at: "2026-10-25T11:00:00.000Z")

        let chapters = try await summary().chapterUsers
        XCTAssertEqual(chapters, .init(today: 2, yesterday: 1, yesterdayUntilNow: 0))
    }

    func testGamePlayersStartedAGameTodayAndLeaveTestDevicesOut() async throws {
        let testDevice = try XCTUnwrap(StatisticsController.testInstallIds.first)
        try await metric("a", "GameView", "didStartGame(whoseFace)", at: "2026-10-25T10:00:00.000Z")
        try await metric("a", "GameView", "didStartGame(whoseVoice)", at: "2026-10-25T10:10:00.000Z")
        try await metric("b", "GameView", "didStartGame(whoseFace)", at: "2026-10-25T12:00:00.000Z")
        try await metric("c", "GameView", "game_music_muted", at: "2026-10-25T12:00:00.000Z")
        try await metric("d", "GameView", "didStartGame(whoseFace)", at: "2026-10-24T22:00:00.000Z")
        try await metric(testDevice, "GameView", "didStartGame(whoseFace)", at: "2026-10-25T12:00:00.000Z")

        let players = try await summary().gamePlayers
        XCTAssertEqual(players, 2)
    }

    func testTopVersionIsTodaysMostUsed() async throws {
        try await signal("a", at: "2026-10-25T10:00:00.000Z", version: "13.6")
        try await signal("b", at: "2026-10-25T10:00:00.000Z", version: "13.6")
        try await signal("c", at: "2026-10-25T10:00:00.000Z", version: "13.5")
        try await signal("d", at: "2026-10-24T10:00:00.000Z", version: "13.5")
        try await signal("e", at: "2026-10-24T10:00:00.000Z", version: "13.5")

        let topVersion = try await summary().topVersion
        XCTAssertEqual(topVersion, .init(appVersion: "13.6", uniqueUsers: 2, percentage: 66.7))
    }

    func testEmptyDayHasNoTopVersion() async throws {
        let response = try await summary()
        XCTAssertNil(response.topVersion)
        XCTAssertEqual(response.activeUsers, .init(today: 0, yesterday: 0, yesterdayUntilNow: 0))
    }

    func testRouteNeedsTheAnalyticsPassword() async throws {
        try await app.test(.GET, "api/v4/widget-summary/wrong") { res async in
            XCTAssertEqual(res.status, .forbidden)
        }
        try await app.test(.GET, "api/v4/widget-summary/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNoThrow(try res.content.decode(WidgetSummaryResponse.self))
        }
    }
}
