@testable import App
import XCTVapor
import Fluent
import Foundation

final class GamesAnalyticsTests: XCTestCase {

    // MARK: - Parsing

    func testParsesEveryGameEvent() {
        XCTAssertEqual(action("GameView", "didStartGame(whoseFace)"), .started(game: "whoseFace"))
        XCTAssertEqual(
            action("GameView", "didFinishGame(whoseFace, score: 7350, hits: 8, rounds: 10, avgSeconds: 3.4, newRecord: true)"),
            .finished(game: "whoseFace", score: 7350, hits: 8, rounds: 10, averageSeconds: 3.4, isNewRecord: true)
        )
        XCTAssertEqual(
            action("GameView", "didFinishGame(whoseVoice, score: 6, hits: 6, rounds: 10, avgSeconds: nil, newRecord: false)"),
            .finished(game: "whoseVoice", score: 6, hits: 6, rounds: 10, averageSeconds: nil, isNewRecord: false)
        )
        XCTAssertEqual(
            action("GameView", "didAbandonGame(whoseVoice, round: 3, of: 10, answered: true)"),
            .abandoned(game: "whoseVoice", round: 3, totalRounds: 10, answered: true)
        )
        XCTAssertEqual(action("GameView", "game_music_muted"), .musicMuted)
        XCTAssertEqual(action("GameView", "game_music_unmuted"), .musicUnmuted)
        XCTAssertEqual(
            action("GameView", "didFindBrokenAuthorPhoto(1A2B-3C)"),
            .brokenAuthorPhoto(authorId: "1A2B-3C")
        )
        XCTAssertEqual(
            action("GameShareView", "didShareGameResult(whoseFace, format: stories, to: com.burbn.instagram.shareextension)"),
            .shared(game: "whoseFace", format: "stories", destination: "com.burbn.instagram.shareextension")
        )
        XCTAssertEqual(action("SupportPrompt", "support_sheet_shown(trigger=games)"), .supportSheetShown)
    }

    func testIgnoresOtherAndMalformedEvents() {
        XCTAssertNil(action("SupportPrompt", "support_sheet_shown(trigger=share_clip)"))
        XCTAssertNil(action("NowPlaying", "didStartGame(whoseFace)"))
        XCTAssertNil(action("GameView", "didFinishGame(whoseFace, score: 10)"))
        XCTAssertNil(action("GameView", "didStartGame(whoseFace) "))
    }

    func testComparesVersionsNumberByNumber() {
        XCTAssertTrue(GameUsageEvent.appVersion("13.6", isAtLeast: "13.6"))
        XCTAssertTrue(GameUsageEvent.appVersion("13.6.1", isAtLeast: "13.6"))
        XCTAssertTrue(GameUsageEvent.appVersion("13.10", isAtLeast: "13.6"))
        XCTAssertTrue(GameUsageEvent.appVersion("14.0", isAtLeast: "13.6"))
        XCTAssertFalse(GameUsageEvent.appVersion("13.5.2", isAtLeast: "13.6"))
        XCTAssertFalse(GameUsageEvent.appVersion("9.9", isAtLeast: "13.6"))
    }

    // MARK: - Counting

    func testCountsPlayersAndFunnel() throws {
        let events = [
            event("a", "2026-10-16T10:00:00.000Z", .started(game: "whoseFace")),
            event("a", "2026-10-16T10:02:00.000Z", .finished(game: "whoseFace", score: 8000, hits: 9, rounds: 10, averageSeconds: 2.5, isNewRecord: true)),
            event("a", "2026-10-17T09:00:00.000Z", .started(game: "whoseVoice")),
            event("a", "2026-10-17T09:01:00.000Z", .abandoned(game: "whoseVoice", round: 2, totalRounds: 10, answered: false)),
            event("b", "2026-10-17T11:00:00.000Z", .started(game: "whoseFace")),
            event("b", "2026-10-17T11:03:00.000Z", .finished(game: "whoseFace", score: 4000, hits: 5, rounds: 10, averageSeconds: nil, isNewRecord: false)),
            event("b", "2026-10-17T11:04:00.000Z", .shared(game: "whoseFace", format: "square", destination: "unknown")),
            event("c", "2026-10-17T12:00:00.000Z", .started(game: "whoseFace")),
            event("c", "2026-10-17T12:01:00.000Z", .abandoned(game: "whoseFace", round: 2, totalRounds: 10, answered: true)),
            event("c", "2026-10-17T12:01:30.000Z", .musicMuted),
            event("c", "2026-10-17T12:02:00.000Z", .supportSheetShown)
        ]

        let response = GamesAnalyticsResponse(
            events: events.shuffled(),
            dayList: ["2026-10-16", "2026-10-17", "2026-10-18"],
            since: "2026-10-16T00:00:00.000Z",
            activeUsers: 10,
            activeUsersWithGames: 8,
            generatedAt: "2026-10-18T00:00:00.000Z"
        )

        XCTAssertEqual(response.days, 3)
        XCTAssertEqual(response.players, 3)
        XCTAssertEqual(response.playerPercentage, 37.5)
        XCTAssertEqual(response.returningPlayers, 1)
        XCTAssertEqual(response.finishers, 2)
        XCTAssertEqual(response.starts, 4)
        XCTAssertEqual(response.finishes, 2)
        XCTAssertEqual(response.abandons, 2)
        XCTAssertEqual(response.completionPercentage, 50)
        XCTAssertEqual(response.shares, 1)
        XCTAssertEqual(response.sharesByFormat, [GamesAnalyticsNameCount(name: "square", count: 1)])
        XCTAssertEqual(response.musicMutedCount, 1)
        XCTAssertEqual(response.supportSheetShownCount, 1)

        XCTAssertEqual(response.daily, [
            GamesAnalyticsDay(date: "2026-10-16", players: 1, newPlayers: 1, starts: 1, finishes: 1),
            GamesAnalyticsDay(date: "2026-10-17", players: 3, newPlayers: 2, starts: 3, finishes: 1),
            GamesAnalyticsDay(date: "2026-10-18", players: 0, newPlayers: 0, starts: 0, finishes: 0)
        ])

        XCTAssertEqual(response.games.map(\.game), ["whoseFace", "whoseVoice"])
        let face = try XCTUnwrap(response.games.first)
        XCTAssertEqual(face.players, 3)
        XCTAssertEqual(face.starts, 3)
        XCTAssertEqual(face.finishes, 2)
        XCTAssertEqual(face.completionPercentage, 66.67)
        XCTAssertEqual(face.averageScore, 6000)
        XCTAssertEqual(face.averageHits, 7)
        XCTAssertEqual(face.averageSecondsPerRound, 2.5)
        XCTAssertEqual(face.newRecords, 1)
        XCTAssertEqual(face.hitsDistribution, [
            GamesAnalyticsHitsCount(hits: 5, finishes: 1),
            GamesAnalyticsHitsCount(hits: 9, finishes: 1)
        ])
        XCTAssertEqual(face.abandonsByRound, [GamesAnalyticsRoundCount(round: 2, abandons: 1, answered: 1)])
        XCTAssertEqual(face.shares, 1)

        let voice = try XCTUnwrap(response.games.last)
        XCTAssertEqual(voice.finishes, 0)
        XCTAssertNil(voice.averageScore)
        XCTAssertNil(voice.averageSecondsPerRound)
        XCTAssertEqual(voice.abandonsByRound, [GamesAnalyticsRoundCount(round: 2, abandons: 1, answered: 0)])
    }

    func testEmptyWindowHasNoPercentages() {
        let response = GamesAnalyticsResponse(
            events: [],
            dayList: ["2026-10-18"],
            since: "2026-10-18T00:00:00.000Z",
            activeUsers: 0,
            activeUsersWithGames: 0,
            generatedAt: "2026-10-18T00:00:00.000Z"
        )
        XCTAssertEqual(response.players, 0)
        XCTAssertEqual(response.playerPercentage, 0)
        XCTAssertEqual(response.completionPercentage, 0)
        XCTAssertEqual(response.games, [])
        XCTAssertEqual(response.daily.count, 1)
    }

    // MARK: - Endpoint

    func testEndpointCountsRecentGamesOutsideTestDevices() async throws {
        TestEnvironment.configurePasswords()
        let app = try await Application.make(.testing)
        do {
            try await configure(app)

            let recent = Date().addingTimeInterval(-60).iso8601withFractionalSeconds
            let old = Date().addingTimeInterval(-40 * 24 * 60 * 60).iso8601withFractionalSeconds
            let testInstall = "0A4D4541-BC16-4C15-842E-DA6ACF957027"

            for metric in [
                Self.metric("a", "GameView", "didStartGame(whoseFace)", recent),
                Self.metric("a", "GameView", "didFinishGame(whoseFace, score: 9100, hits: 10, rounds: 10, avgSeconds: 1.9, newRecord: true)", recent),
                Self.metric("b", "GameView", "didStartGame(whoseVoice)", recent),
                Self.metric("b", "NowPlaying", "didTapShareClip", recent),
                Self.metric("old", "GameView", "didStartGame(whoseFace)", old),
                Self.metric(testInstall, "GameView", "didStartGame(whoseFace)", recent)
            ] {
                try await metric.create(on: app.db)
            }
            for signal in [
                Self.signal("a", "13.6", recent),
                Self.signal("b", "13.10", recent),
                Self.signal("c", "13.5", recent),
                Self.signal("old", "13.6", old),
                Self.signal("sim", "13.6", recent, modelName: "iPhone 17 Simulator")
            ] {
                try await signal.create(on: app.db)
            }

            try await app.test(.GET, "api/v4/games-analytics/wrong-password") { res async throws in
                XCTAssertEqual(res.status, .forbidden)
            }

            try await app.test(.GET, "api/v4/games-analytics/\(TestEnvironment.testPassword)?days=7") { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(GamesAnalyticsResponse.self)
                XCTAssertEqual(body.days, 7)
                XCTAssertEqual(body.daily.count, 7)
                XCTAssertEqual(body.activeUsers, 3)
                XCTAssertEqual(body.activeUsersWithGames, 2)
                XCTAssertEqual(body.players, 2)
                XCTAssertEqual(body.playerPercentage, 100)
                XCTAssertEqual(body.starts, 2)
                XCTAssertEqual(body.finishes, 1)
                XCTAssertEqual(body.daily.map(\.starts).reduce(0, +), 2)
                XCTAssertEqual(Set(body.games.map(\.game)), ["whoseFace", "whoseVoice"])
            }
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    // MARK: - Helpers

    private func action(_ originatingScreen: String, _ destinationScreen: String) -> GameUsageEvent.Action? {
        GameUsageEvent(
            installId: "install",
            originatingScreen: originatingScreen,
            destinationScreen: destinationScreen,
            dateTime: "2026-10-18T12:00:00.000Z"
        )?.action
    }

    private func event(_ installId: String, _ dateTime: String, _ action: GameUsageEvent.Action) -> GameUsageEvent {
        GameUsageEvent(installId: installId, dateTime: dateTime, action: action)
    }

    private static func metric(_ installId: String, _ originatingScreen: String, _ destinationScreen: String, _ dateTime: String) -> UsageMetric {
        UsageMetric(
            customInstallId: installId,
            originatingScreen: originatingScreen,
            destinationScreen: destinationScreen,
            systemName: "iOS",
            isiOSAppOnMac: false,
            appVersion: "13.6",
            dateTime: dateTime,
            currentTimeZone: "America/Sao_Paulo"
        )
    }

    private static func signal(_ installId: String, _ appVersion: String, _ dateTime: String, modelName: String = "iPhone 17") -> StillAliveSignal {
        StillAliveSignal(
            installId: installId,
            modelName: modelName,
            systemName: "iOS",
            systemVersion: "26.0",
            isiOSAppOnMac: false,
            appVersion: appVersion,
            currentTimeZone: "America/Sao_Paulo",
            dateTime: dateTime
        )
    }
}
