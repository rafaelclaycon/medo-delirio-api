@testable import App
import XCTVapor
import Fluent

final class ElectionLiveUsageSeriesTests: XCTestCase {

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

    func testEveryBucketIsPresentEvenWhenEmpty() {
        let result = series([])
        XCTAssertEqual(result.buckets.count, 6)
        XCTAssertEqual(result.buckets.map(\.start), (0..<6).map { at("2026-10-04T20:00:00Z").addingTimeInterval(Double($0) * 600) })
        XCTAssertTrue(result.buckets.allSatisfy { $0.starters == 0 && $0.cumulativeStarters == 0 && $0.watchingEstimate == 0 })
    }

    func testSinceIsRoundedDownAndTheLastBucketCanBePartial() {
        let result = series([], since: "2026-10-04T20:03:00Z", until: "2026-10-04T20:55:00Z")
        XCTAssertEqual(result.since, at("2026-10-04T20:00:00Z"))
        XCTAssertEqual(result.buckets.count, 6)
        XCTAssertEqual(result.buckets.last?.start, at("2026-10-04T20:50:00Z"))
    }

    func testAnInstallIsNewOnlyOnceAndTheTotalOnlyGrows() {
        let result = series([
            start("a", "2026-10-04T20:05:00Z"),
            start("a", "2026-10-04T20:25:00Z"),
            start("b", "2026-10-04T20:26:00Z"),
            start("c", "2026-10-04T20:51:00Z")
        ])
        XCTAssertEqual(result.buckets.map(\.starters), [1, 0, 2, 0, 0, 1])
        XCTAssertEqual(result.buckets.map(\.newStarters), [1, 0, 1, 0, 0, 1])
        XCTAssertEqual(result.buckets.map(\.cumulativeStarters), [1, 1, 2, 2, 2, 3])
        XCTAssertEqual(result.uniqueStarters, 3)
        XCTAssertEqual(result.totalStarts, 4)
    }

    func testEventsOutsideTheWindowDontCountAsStarts() {
        let result = series([
            start("early", "2026-10-04T19:30:00Z"),
            start("late", "2026-10-04T21:00:00Z")
        ])
        XCTAssertEqual(result.uniqueStarters, 0)
        XCTAssertEqual(result.buckets.last?.cumulativeStarters, 0)
    }

    // MARK: - Watching

    func testAStartBeforeTheWindowCountsAsWatching() {
        let result = series([start("a", "2026-10-04T19:00:00Z")])
        XCTAssertEqual(result.buckets.map(\.watchingEstimate), [1, 1, 1, 1, 1, 1])
        XCTAssertEqual(result.uniqueStarters, 0)
    }

    func testAStopEndsWatching() {
        let result = series([
            start("a", "2026-10-04T20:05:00Z"),
            stop("a", "2026-10-04T20:35:00Z")
        ])
        XCTAssertEqual(result.buckets.map(\.watchingEstimate), [1, 1, 1, 0, 0, 0])
        XCTAssertEqual(result.buckets.map(\.stoppers), [0, 0, 0, 1, 0, 0])
        XCTAssertEqual(result.uniqueStoppers, 1)
    }

    func testStartingAgainAfterAStopCountsAsWatchingAgain() {
        let result = series([
            start("a", "2026-10-04T20:05:00Z"),
            stop("a", "2026-10-04T20:15:00Z"),
            start("a", "2026-10-04T20:45:00Z")
        ])
        XCTAssertEqual(result.buckets.map(\.watchingEstimate), [1, 0, 0, 0, 1, 1])
        XCTAssertEqual(result.uniqueStarters, 1)
        XCTAssertEqual(result.totalStarts, 2)
    }

    /// A Live Activity lasts at most 8 hours: 12:30 UTC is still watching at 20:30, not at 20:40.
    func testWatchingEndsAfterEightHours() {
        let result = series([start("a", "2026-10-04T12:30:00Z")])
        XCTAssertEqual(result.buckets.map(\.watchingEstimate), [1, 1, 1, 0, 0, 0])
    }

    func testEventOrderDoesntMatter() {
        let events = [
            start("a", "2026-10-04T20:05:00Z"),
            stop("a", "2026-10-04T20:35:00Z"),
            start("b", "2026-10-04T20:12:00Z")
        ]
        XCTAssertEqual(series(events), series(events.reversed()))
    }

    // MARK: - Labels and parsing

    func testBrasiliaLabelsAcrossUTCMidnight() {
        XCTAssertEqual(Series.brasiliaTime(at("2026-10-04T20:00:00Z")), "17:00")
        XCTAssertEqual(Series.brasiliaTime(at("2026-10-04T23:50:00Z")), "20:50")
        XCTAssertEqual(Series.brasiliaTime(at("2026-10-05T00:10:00Z")), "21:10")
    }

    func testParsesDatesWithAndWithoutFractionalSeconds() {
        XCTAssertEqual(Series.parseDate("2026-10-04T21:11:16.123Z")?.timeIntervalSince1970 ?? 0, 1_791_148_276.123, accuracy: 0.001)
        XCTAssertEqual(Series.parseDate("2026-10-04T20:00:00Z"), Date(timeIntervalSince1970: 1_791_144_000))
        XCTAssertNil(Series.parseDate("yesterday"))
    }
}

// MARK: - Route

final class ElectionLiveSeriesRouteTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

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

    func testReturnsTheSeriesFromTheBannerEvents() async throws {
        for metric in [
            event("a", "election_live_activity_started", "2026-10-04T20:05:00.123Z"),
            event("b", "election_live_activity_started", "2026-10-04T20:12:00.000Z"),
            event("b", "election_live_activity_stopped", "2026-10-04T20:31:00.000Z"),
            // Not counted: another screen, and an event after the window.
            event("c", "election_live_activity_started", "2026-10-04T20:06:00.000Z", screen: "ElectionResults"),
            event("d", "election_live_activity_started", "2026-10-04T21:10:00.000Z")
        ] {
            try await metric.create(on: app.db)
        }

        try await app.test(.GET, path("since=2026-10-04T20:00:00Z&until=2026-10-04T21:00:00Z&bucketMinutes=15")) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(ElectionLiveSeriesResponse.self)
            XCTAssertEqual(body.bucketMinutes, 15)
            XCTAssertEqual(body.uniqueStarters, 2)
            XCTAssertEqual(body.uniqueStoppers, 1)
            XCTAssertEqual(body.buckets.map(\.startBrasilia), ["17:00", "17:15", "17:30", "17:45"])
            XCTAssertEqual(body.buckets.map(\.cumulativeStarters), [2, 2, 2, 2])
            XCTAssertEqual(body.buckets.map(\.watchingEstimate), [2, 2, 1, 1])
        }
    }

    func testRejectsAWrongPassword() async throws {
        try await app.test(.GET, path("bucketMinutes=10", password: "wrong")) { res async in
            XCTAssertEqual(res.status, .forbidden)
        }
    }

    func testRejectsBadParameters() async throws {
        for query in [
            "bucketMinutes=7",
            "since=2026-10-04T20:00:00Z&until=2026-10-04T19:00:00Z",
            "since=2026-10-01T00:00:00Z&until=2026-10-04T00:00:00Z",
            "since=yesterday"
        ] {
            try await app.test(.GET, path(query)) { res async in
                XCTAssertEqual(res.status, .badRequest, query)
            }
        }
    }
}
