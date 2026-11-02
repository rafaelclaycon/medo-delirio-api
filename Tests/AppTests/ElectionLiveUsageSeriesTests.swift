@testable import App
import Testing
import VaporTesting
import Foundation
import Fluent

struct ElectionLiveUsageSeriesTests {

    private typealias Series = ElectionLiveUsageSeries

    private func at(_ string: String) -> Date {
        Series.parseDate(string)!
    }

    private func start(_ installId: String, _ time: String) -> Series.Event {
        Series.Event(installId: installId, kind: .started, at: at(time))
    }

    private func stop(_ installId: String, _ time: String) -> Series.Event {
        Series.Event(installId: installId, kind: .stopped, at: at(time))
    }

    /// 17h to 18h Brasília in 10-minute buckets.
    private func series(_ events: [Series.Event], since: String = "2026-10-04T20:00:00Z", until: String = "2026-10-04T21:00:00Z") -> Series {
        Series(events: events, since: at(since), until: at(until), bucketSeconds: 600)
    }

    // MARK: - Buckets

    @Test func `Every bucket is present even when empty`() {
        let result = series([])
        #expect(result.buckets.count == 6)
        #expect(result.buckets.map(\.start) == (0..<6).map { at("2026-10-04T20:00:00Z").addingTimeInterval(Double($0) * 600) })
        #expect(result.buckets.allSatisfy { $0.starters == 0 && $0.cumulativeStarters == 0 && $0.watchingEstimate == 0 })
    }

    @Test func `Since is rounded down and the last bucket can be partial`() {
        let result = series([], since: "2026-10-04T20:03:00Z", until: "2026-10-04T20:55:00Z")
        #expect(result.since == at("2026-10-04T20:00:00Z"))
        #expect(result.buckets.count == 6)
        #expect(result.buckets.last?.start == at("2026-10-04T20:50:00Z"))
    }

    @Test func `An install is new only once and the total only grows`() {
        let result = series([
            start("a", "2026-10-04T20:05:00Z"),
            start("a", "2026-10-04T20:25:00Z"),
            start("b", "2026-10-04T20:26:00Z"),
            start("c", "2026-10-04T20:51:00Z")
        ])
        #expect(result.buckets.map(\.starters) == [1, 0, 2, 0, 0, 1])
        #expect(result.buckets.map(\.newStarters) == [1, 0, 1, 0, 0, 1])
        #expect(result.buckets.map(\.cumulativeStarters) == [1, 1, 2, 2, 2, 3])
        #expect(result.uniqueStarters == 3)
        #expect(result.totalStarts == 4)
    }

    @Test func `Events outside the window don't count as starts`() {
        let result = series([
            start("early", "2026-10-04T19:30:00Z"),
            start("late", "2026-10-04T21:00:00Z")
        ])
        #expect(result.uniqueStarters == 0)
        #expect(result.buckets.last?.cumulativeStarters == 0)
    }

    // MARK: - Watching

    @Test func `A start before the window counts as watching`() {
        let result = series([start("a", "2026-10-04T19:00:00Z")])
        #expect(result.buckets.map(\.watchingEstimate) == [1, 1, 1, 1, 1, 1])
        #expect(result.uniqueStarters == 0)
    }

    @Test func `A stop ends watching`() {
        let result = series([
            start("a", "2026-10-04T20:05:00Z"),
            stop("a", "2026-10-04T20:35:00Z")
        ])
        #expect(result.buckets.map(\.watchingEstimate) == [1, 1, 1, 0, 0, 0])
        #expect(result.buckets.map(\.stoppers) == [0, 0, 0, 1, 0, 0])
        #expect(result.uniqueStoppers == 1)
    }

    @Test func `Starting again after a stop counts as watching again`() {
        let result = series([
            start("a", "2026-10-04T20:05:00Z"),
            stop("a", "2026-10-04T20:15:00Z"),
            start("a", "2026-10-04T20:45:00Z")
        ])
        #expect(result.buckets.map(\.watchingEstimate) == [1, 0, 0, 0, 1, 1])
        #expect(result.uniqueStarters == 1)
        #expect(result.totalStarts == 2)
    }

    /// A Live Activity lasts at most 8 hours: 12:30 UTC is still watching at 20:30, not at 20:40.
    @Test func `Watching ends after eight hours`() {
        let result = series([start("a", "2026-10-04T12:30:00Z")])
        #expect(result.buckets.map(\.watchingEstimate) == [1, 1, 1, 0, 0, 0])
    }

    @Test func `Event order doesn't matter`() {
        let events = [
            start("a", "2026-10-04T20:05:00Z"),
            stop("a", "2026-10-04T20:35:00Z"),
            start("b", "2026-10-04T20:12:00Z")
        ]
        #expect(series(events) == series(events.reversed()))
    }

    // MARK: - Labels and parsing

    @Test func `Brasília labels across UTC midnight`() {
        #expect(Series.brasiliaTime(at("2026-10-04T20:00:00Z")) == "17:00")
        #expect(Series.brasiliaTime(at("2026-10-04T23:50:00Z")) == "20:50")
        #expect(Series.brasiliaTime(at("2026-10-05T00:10:00Z")) == "21:10")
    }

    @Test func `Parses dates with and without fractional seconds`() {
        #expect(abs((Series.parseDate("2026-10-04T21:11:16.123Z")?.timeIntervalSince1970 ?? 0) - 1_791_148_276.123) <= 0.001)
        #expect(Series.parseDate("2026-10-04T20:00:00Z") == Date(timeIntervalSince1970: 1_791_144_000))
        #expect(Series.parseDate("yesterday") == nil)
    }
}

// MARK: - Route

struct ElectionLiveSeriesRouteTests {

    private func event(_ installId: String, _ action: String, _ dateTime: String, screen: String = "ElectionLiveBanner") -> UsageMetric {
        UsageMetric(
            customInstallId: installId,
            originatingScreen: screen,
            destinationScreen: action,
            systemName: "iOS",
            isiOSAppOnMac: false,
            appVersion: "13.1",
            dateTime: dateTime,
            currentTimeZone: "BRT"
        )
    }

    private func path(_ query: String, password: String = TestEnvironment.testPassword) -> String {
        "api/v4/election-live-analytics/series/\(password)?\(query)"
    }

    @Test func `Returns the series from the banner events`() async throws {
        try await withTestApp { app in
            for metric in [
                event("a", "election_live_activity_started", "2026-10-04T20:05:00.123Z"),
                event("b", "election_live_activity_started", "2026-10-04T20:12:00.000Z"),
                event("b", "election_live_activity_stopped", "2026-10-04T20:31:00.000Z"),
                // The results screen counts like the banner.
                event("e", "election_live_activity_started", "2026-10-04T20:40:00.000Z", screen: "ElectionResults"),
                // Not counted: another screen, and an event after the window.
                event("c", "election_live_activity_started", "2026-10-04T20:06:00.000Z", screen: "SoundsList"),
                event("d", "election_live_activity_started", "2026-10-04T21:10:00.000Z")
            ] {
                try await metric.create(on: app.db)
            }

            try await app.testing().test(.GET, path("since=2026-10-04T20:00:00Z&until=2026-10-04T21:00:00Z&bucketMinutes=15")) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(ElectionLiveSeriesResponse.self)
                #expect(body.bucketMinutes == 15)
                #expect(body.uniqueStarters == 3)
                #expect(body.uniqueStoppers == 1)
                #expect(body.buckets.map(\.startBrasilia) == ["17:00", "17:15", "17:30", "17:45"])
                #expect(body.buckets.map(\.cumulativeStarters) == [2, 2, 3, 3])
                #expect(body.buckets.map(\.watchingEstimate) == [2, 2, 2, 2])
            }
        }
    }

    /// The summary endpoint counts the results screen like the banner, and skips other screens.
    @Test func `Summary counts the banner and the results screen`() async throws {
        try await withTestApp { app in
            for metric in [
                event("a", "election_live_activity_started", "2026-10-04T20:05:00.000Z"),
                event("a", "election_live_activity_stopped", "2026-10-04T20:20:00.000Z"),
                event("e", "election_live_activity_started", "2026-10-04T20:40:00.000Z", screen: "ElectionResults"),
                event("c", "election_live_activity_started", "2026-10-04T20:06:00.000Z", screen: "SoundsList")
            ] {
                try await metric.create(on: app.db)
            }

            try await app.testing().test(.GET, "api/v4/election-live-analytics/\(TestEnvironment.testPassword)?since=2026-10-04T20:00:00Z") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(ElectionLiveAnalyticsResponse.self)
                #expect(body.uniqueStarters == 2)
                #expect(body.totalStarts == 2)
                #expect(body.uniqueStoppers == 1)
                #expect(body.startersByVersion.map(\.starters) == [2])
            }
        }
    }

    @Test func `Rejects a wrong password`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, path("bucketMinutes=10", password: "wrong")) { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    @Test(arguments: [
        "bucketMinutes=7",
        "since=2026-10-04T20:00:00Z&until=2026-10-04T19:00:00Z",
        "since=2026-10-01T00:00:00Z&until=2026-10-04T00:00:00Z",
        "since=yesterday"
    ])
    func `Rejects bad parameters`(query: String) async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, path(query)) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }
}
