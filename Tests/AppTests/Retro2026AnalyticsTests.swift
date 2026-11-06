@testable import App
import Testing
import VaporTesting
import Fluent
import FluentSQLiteDriver
import Foundation

struct Retro2026AnalyticsTests {

    private func action(_ screen: String, _ destination: String) -> RetroUsageEvent.Action? {
        RetroUsageEvent(
            installId: "a",
            originatingScreen: screen,
            destinationScreen: destination,
            dateTime: "2026-12-10T12:00:00.000Z",
            appVersion: "13.9",
            systemName: "iOS",
            isiOSAppOnMac: false
        )?.action
    }

    private func event(
        _ installId: String,
        _ dateTime: String,
        _ action: RetroUsageEvent.Action,
        version: String = "13.9",
        system: String = "iOS",
        mac: Bool = false
    ) -> RetroUsageEvent {
        RetroUsageEvent(installId: installId, dateTime: dateTime, appVersion: version, systemName: system, isiOSAppOnMac: mac, action: action)
    }

    private func stats(shares: Int, first: String = "Fudeu", author: String? = "Jair Bolsonaro", minutes: Int? = 90) -> RetroUsageEvent.Action {
        .stats(RetroShareStats(
            ranking: [first, "Eu prefiro morrer"],
            shareCount: shares,
            favoriteDay: shares > 0 ? "Sexta-feira" : nil,
            author: author,
            listeningMinutes: minutes,
            topEpisode: minutes == nil ? nil : "Episódio 300"
        ))
    }

    // MARK: - Parsing

    @Test func `Parses the banner, close and share events`() {
        #expect(action("Retro2026", "didShowRetroBanner") == .bannerShown)
        #expect(action("Retro2026", "didOpenRetroFromBanner") == .openedFromBanner)
        #expect(action("Retro2026", "didDismissRetroBanner") == .bannerDismissed)
        #expect(action("Retro2026", "didTapRetroShareButton") == .shareTapped)
        #expect(
            action("Retro2026", "didCloseRetroStories; topSound1; 6; 9; swipeDown")
                == .closed(page: "topSound1", pageNumber: 6, pageCount: 9, reason: "swipeDown")
        )
        #expect(
            action("Retro2026", "didCloseRetroStories; loading; 0; 0; closeButton")
                == .closed(page: "loading", pageNumber: 0, pageCount: 0, reason: "closeButton")
        )
    }

    @Test func `Ignores other screens and malformed events`() {
        #expect(action("Retro2025", "didShowRetroBanner") == nil)
        #expect(action("NowPlaying", "didShowRetroBanner") == nil)
        #expect(action("Retro2026", "didCloseRetroStories; topSound1; 6") == nil)
        #expect(action("Retro2026", "didCloseRetroStories; topSound1; six; 9; swipeDown") == nil)
        #expect(action("Retro2026", "something else") == nil)
    }

    @Test func `Parses a full 2026 stats string`() {
        let text = "1 Fudeu, 2 Eu prefiro morrer, 3 Rapaz; 120 compart; Sexta-feira; Jair Bolsonaro; https://example.com/photo.jpg; 340 min; Episódio 300: o fim"
        #expect(action("Retro2026", text) == .stats(RetroShareStats(
            ranking: ["Fudeu", "Eu prefiro morrer", "Rapaz"],
            shareCount: 120,
            favoriteDay: "Sexta-feira",
            author: "Jair Bolsonaro",
            listeningMinutes: 340,
            topEpisode: "Episódio 300: o fim"
        )))
    }

    @Test func `Keeps commas and semicolons inside names and titles`() {
        let text = "1 A gente tá fodido, a gente tá muito fodido, 2 Puta que pariu; Marquinho; 7 compart; Terça-feira; Fulano; no-photo; 12 min; Parte 1; parte 2"
        #expect(RetroShareStats(text) == RetroShareStats(
            ranking: ["A gente tá fodido, a gente tá muito fodido", "Puta que pariu; Marquinho"],
            shareCount: 7,
            favoriteDay: "Terça-feira",
            author: "Fulano",
            listeningMinutes: 12,
            topEpisode: "Parte 1; parte 2"
        ))
    }

    @Test func `Reads the no-author, no-episodes and never-shared tokens`() {
        #expect(RetroShareStats("; 0 compart; -; no-author; no-episodes") == RetroShareStats(
            ranking: [],
            shareCount: 0,
            favoriteDay: nil,
            author: nil
        ))
    }

    @Test func `Parses a 2025 stats string, which has no episode part`() {
        let text = "1 Rapaz, 2 Funk do Xandão; 120 compart; Quinta-feira; Jair Bolsonaro; https://example.com/photo.jpg.webp"
        #expect(action("Retro2025", text) == .stats(RetroShareStats(
            ranking: ["Rapaz", "Funk do Xandão"],
            shareCount: 120,
            favoriteDay: "Quinta-feira",
            author: "Jair Bolsonaro"
        )))
    }

    @Test(arguments: [
        "1 Fudeu; Sexta-feira; Fulano; no-photo",
        "1 Fudeu; 10 compart; Sexta-feira; Fulano",
        "1 Fudeu; 10 compart; Sexta-feira; no-author; muito tempo; Episódio"
    ])
    func `Rejects stats strings that don't fit`(text: String) {
        #expect(RetroShareStats(text) == nil)
    }

    // MARK: - Counting

    @Test func `Counts the funnel by install`() {
        let events = [
            event("a", "2026-12-01T10:00:00.000Z", .bannerShown),
            event("a", "2026-12-01T18:00:00.000Z", .bannerShown),
            event("a", "2026-12-01T18:00:05.000Z", .openedFromBanner),
            event("a", "2026-12-01T18:03:00.000Z", .closed(page: "share", pageNumber: 9, pageCount: 9, reason: "tappedPastEnd")),
            event("b", "2026-12-02T10:00:00.000Z", .bannerShown),
            event("b", "2026-12-02T10:00:03.000Z", .openedFromBanner),
            event("b", "2026-12-02T10:02:00.000Z", .shareTapped),
            event("b", "2026-12-02T10:02:00.100Z", stats(shares: 30)),
            event("c", "2026-12-02T11:00:00.000Z", .bannerShown),
            event("c", "2026-12-02T11:00:02.000Z", .openedFromBanner),
            event("c", "2026-12-02T11:00:30.000Z", .closed(page: "topSound1", pageNumber: 6, pageCount: 9, reason: "swipeDown")),
            event("c", "2026-12-02T12:00:00.000Z", .openedFromBanner),
            event("d", "2026-12-02T13:00:00.000Z", .bannerShown),
            event("d", "2026-12-02T13:00:01.000Z", .bannerDismissed)
        ]

        let response = Retro2026AnalyticsResponse(events: events.shuffled(), events2025: [], today: "2026-12-03", generatedAt: "now")

        #expect(response.funnel == Retro2026Funnel(
            shown: 4, opened: 3, reachedEnd: 2, tappedShare: 1, dismissed: 1,
            openRate: 75, completionRate: 66.67, shareRate: 33.33, dismissRate: 25
        ))
        #expect(response.bannerImpressions == 5)
        #expect(response.opens == 4)
        #expect(response.closes == 2)
        #expect(response.opensWithoutClose == 2)
        #expect(response.shareTaps == 1)
        #expect(response.firstEventAt == "2026-12-01T10:00:00.000Z")
        #expect(response.daily == [
            Retro2026Day(date: "2026-12-01", shown: 1, opened: 1, tappedShare: 0),
            Retro2026Day(date: "2026-12-02", shown: 3, opened: 2, tappedShare: 1),
            Retro2026Day(date: "2026-12-03", shown: 0, opened: 0, tappedShare: 0)
        ])
    }

    @Test func `Splits drop-off by furthest page and reason, in display order`() {
        let events = [
            event("a", "2026-12-01T10:00:00.000Z", .closed(page: "topSound1", pageNumber: 6, pageCount: 9, reason: "swipeDown")),
            event("b", "2026-12-01T10:00:00.000Z", .closed(page: "topSound1", pageNumber: 5, pageCount: 8, reason: "closeButton")),
            event("c", "2026-12-01T10:00:00.000Z", .closed(page: "loading", pageNumber: 0, pageCount: 0, reason: "swipeDown")),
            event("d", "2026-12-01T10:00:00.000Z", .closed(page: "share", pageNumber: 9, pageCount: 9, reason: "tappedPastEnd")),
            event("e", "2026-12-01T10:00:00.000Z", .closed(page: "newPage", pageNumber: 3, pageCount: 9, reason: "shake"))
        ]

        let response = Retro2026AnalyticsResponse(events: events, events2025: [], today: "2026-12-01", generatedAt: "now")

        #expect(response.dropOff.map(\.page) == ["loading"] + RetroUsageEvent.pages + ["newPage"])
        #expect(response.dropOff.first { $0.page == "topSound1" } == Retro2026PageDropOff(
            page: "topSound1", closeButton: 1, swipeDown: 1, tappedPastEnd: 0, other: 0, total: 2
        ))
        #expect(response.dropOff.first { $0.page == "newPage" }?.other == 1)
        #expect(response.closesBeforeLoading == 1)
        #expect(response.dropOff.first { $0.page == "intro" }?.total == 0)
    }

    @Test func `Breaks the steps down by version, system and Mac`() {
        let events = [
            event("a", "2026-12-01T10:00:00.000Z", .bannerShown, version: "13.10"),
            event("a", "2026-12-01T10:00:01.000Z", .openedFromBanner, version: "13.10"),
            event("b", "2026-12-01T10:00:00.000Z", .bannerShown, version: "13.9", system: "iPadOS"),
            event("c", "2026-12-01T10:00:00.000Z", .bannerShown, version: "13.9", mac: true),
            event("c", "2026-12-01T10:00:01.000Z", .openedFromBanner, version: "13.9", mac: true),
            event("c", "2026-12-01T10:01:00.000Z", .shareTapped, version: "13.9", mac: true)
        ]

        let response = Retro2026AnalyticsResponse(events: events, events2025: [], today: "2026-12-01", generatedAt: "now")

        #expect(response.byAppVersion == [
            Retro2026Breakdown(name: "13.10", shown: 1, opened: 1, tappedShare: 0),
            Retro2026Breakdown(name: "13.9", shown: 2, opened: 1, tappedShare: 1)
        ])
        #expect(response.bySystemName == [
            Retro2026Breakdown(name: "iOS", shown: 2, opened: 2, tappedShare: 1),
            Retro2026Breakdown(name: "iPadOS", shown: 1, opened: 0, tappedShare: 0)
        ])
        #expect(response.byMac == [
            Retro2026Breakdown(name: "false", shown: 2, opened: 1, tappedShare: 0),
            Retro2026Breakdown(name: "true", shown: 1, opened: 1, tappedShare: 1)
        ])
    }

    @Test func `Sums up the stats once per install, keeping the latest`() {
        let events = [
            event("a", "2026-12-01T10:00:00.000Z", stats(shares: 5, first: "Rapaz")),
            event("a", "2026-12-02T10:00:00.000Z", stats(shares: 8, first: "Fudeu")),
            event("b", "2026-12-02T10:00:00.000Z", stats(shares: 120, first: "Fudeu", author: nil, minutes: nil)),
            event("c", "2026-12-02T11:00:00.000Z", stats(shares: 0, first: "Comunista", minutes: 700))
        ]

        let summary = Retro2026AnalyticsResponse(events: events, events2025: [], today: "2026-12-02", generatedAt: "now").stats

        #expect(summary.shareTaps == 4)
        #expect(summary.people == 3)
        #expect(summary.topFirstSounds == [RetroNameCount(name: "Fudeu", count: 2), RetroNameCount(name: "Comunista", count: 1)])
        #expect(summary.topSounds.first == RetroNameCount(name: "Eu prefiro morrer", count: 3))
        #expect(summary.topAuthors == [RetroNameCount(name: "Jair Bolsonaro", count: 2)])
        #expect(summary.withoutAuthor == 1)
        #expect(summary.favoriteDays == [RetroNameCount(name: "Sexta-feira", count: 2), RetroNameCount(name: "Nunca", count: 1)])
        #expect(summary.shareCounts.map(\.count) == [1, 1, 0, 0, 1, 0, 0])
        #expect(summary.medianShareCount == 8)
        #expect(summary.listeningMinutes.map(\.count) == [0, 0, 1, 0, 1])
        #expect(summary.withoutEpisodes == 1)
        #expect(summary.medianListeningMinutes == 395)
    }

    @Test func `Lines up share taps by day since each year's first`() {
        let events2025 = [
            event("x", "2025-12-06T20:00:00.000Z", stats(shares: 10)),
            event("y", "2025-12-06T21:00:00.000Z", stats(shares: 10)),
            event("x", "2025-12-08T10:00:00.000Z", stats(shares: 10))
        ]
        let events2026 = [
            event("a", "2026-12-01T09:00:00.000Z", .bannerShown),
            event("a", "2026-12-02T10:00:00.000Z", stats(shares: 3))
        ]

        let response = Retro2026AnalyticsResponse(events: events2026, events2025: events2025, today: "2026-12-05", generatedAt: "now")

        #expect(response.comparison.daily == [
            RetroComparisonDay(day: 0, retro2025: 2, retro2026: 1),
            RetroComparisonDay(day: 1, retro2025: 0, retro2026: 0),
            RetroComparisonDay(day: 2, retro2025: 1, retro2026: 0),
            RetroComparisonDay(day: 3, retro2025: 0, retro2026: 0)
        ])
        #expect(response.comparison.retro2025.shareTaps == 3)
        #expect(response.comparison.retro2025.people == 2)
    }

    @Test func `Empty before any event`() {
        let response = Retro2026AnalyticsResponse(events: [], events2025: [], today: "2026-11-05", generatedAt: "now")
        #expect(response.firstEventAt == nil)
        #expect(response.daily.isEmpty)
        #expect(response.comparison.daily.isEmpty)
        #expect(response.stats.medianShareCount == nil)
        #expect(response.funnel.openRate == 0)
    }

    // MARK: - Route

    @Test func `Reads only Retrospectiva rows and leaves test devices out`() async throws {
        try await withTestApp { app in
            func metric(_ installId: String, _ screen: String, _ destination: String, at dateTime: String) async throws {
                try await UsageMetric(
                    customInstallId: installId, originatingScreen: screen, destinationScreen: destination,
                    systemName: "iOS", isiOSAppOnMac: false, appVersion: "13.9", dateTime: dateTime, currentTimeZone: "GMT-3"
                ).save(on: app.db)
            }
            let testDevice = try #require(StatisticsController.testInstallIds.first)
            try await metric("a", "Retro2026", "didShowRetroBanner", at: "2026-12-01T10:00:00.000Z")
            try await metric(testDevice, "Retro2026", "didShowRetroBanner", at: "2026-12-01T10:00:00.000Z")
            try await metric("b", "Vírgulas", "didShowRetroBanner", at: "2026-12-01T10:00:00.000Z")
            try await metric("c", "Retro2025", "1 Rapaz; 3 compart; Sábado; no-author", at: "2025-12-10T10:00:00.000Z")

            let sqlite = try #require(app.db as? SQLiteDatabase)
            let now = try #require("2026-12-02T12:00:00.000Z".iso8601withFractionalSeconds)
            let response = try await StatisticsController.retro2026Analytics(on: sqlite, now: now)

            #expect(response.funnel.shown == 1)
            #expect(response.daily.map(\.date) == ["2026-12-01", "2026-12-02"])
            #expect(response.comparison.retro2025.people == 1)

            try await app.testing().test(.GET, "api/v4/retro2026-analytics/wrong") { res async in
                #expect(res.status == .forbidden)
            }
            try await app.testing().test(.GET, "api/v4/retro2026-analytics/\(TestEnvironment.testPassword)") { res async in
                #expect(res.status == .ok)
            }
        }
    }
}
