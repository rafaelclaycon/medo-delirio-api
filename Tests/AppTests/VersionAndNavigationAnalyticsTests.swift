@testable import App
import XCTVapor
import Fluent
import Foundation

final class VersionAndNavigationAnalyticsTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func signal(_ installId: String, version: String, at dateTime: String) async throws {
        try await StillAliveSignal(
            installId: installId, modelName: "iPhone17,1", systemName: "iOS", systemVersion: "26.0",
            isiOSAppOnMac: false, appVersion: version, currentTimeZone: "America/Sao_Paulo", dateTime: dateTime
        ).save(on: app.db)
    }

    private func metric(_ destination: String, from origin: String = "soundsTab", at dateTime: String) async throws {
        try await UsageMetric(
            customInstallId: "install", originatingScreen: origin, destinationScreen: destination,
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

    private func jsonObject(_ res: XCTHTTPResponse) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView))
    }

    // MARK: - navigation-analytics

    func testNavigationAnalyticsGroupsScreensFromTheLast30Days() async throws {
        for _ in 0..<5 { try await metric("soundsTab", at: daysAgo(1)) }
        for i in 0..<4 { try await metric("didViewReaction_\(i)", at: daysAgo(2)) }
        for _ in 0..<3 { try await metric("didViewReactionsTab", at: daysAgo(3)) }
        try await metric("didAddManySoundsToFavorites_3", at: daysAgo(1))
        try await metric("didAddManySoundsToFavorites_10", at: daysAgo(1))
        try await metric("didPlayRandomSound_abc", at: daysAgo(1))
        try await metric("didPlayRandomSound_def", at: daysAgo(1))
        try await metric("didPlayRandomSound_ghi", at: daysAgo(1))
        try await metric("didPlayRandomSound_jkl", at: daysAgo(1))
        try await metric("didPlayRandomSound_mno", at: daysAgo(1))
        try await metric("didPlayRandomSound_pqr", at: daysAgo(1))
        for i in 0..<7 { try await metric("pinnedReaction_\(i)", at: daysAgo(1)) }
        // Left out: Retro screens, empty destinations and old metrics.
        try await metric("soundsTab", from: "Retro2025Story", at: daysAgo(1))
        try await metric("soundsTab", from: "showRETRO", at: daysAgo(1))
        try await metric("", at: daysAgo(1))
        try await metric("soundsTab", at: daysAgo(40))

        try await app.test(.GET, "api/v3/navigation-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["top_screens", "total_views"])
            let response = try res.content.decode(NavigationAnalyticsResponse.self)
            XCTAssertEqual(response.top_screens.map { "\($0.id) \($0.screen_name) \($0.view_count)" }, [
                "pinnedReaction pinnedReaction 7",
                "didPlayRandomSound didPlayRandomSound 6",
                "soundsTab soundsTab 5",
                "didViewSpecificReaction didViewSpecificReaction 4",
                "didViewReactionsTab didViewReactionsTab 3",
                "didAddManySoundsToFavorites didAddManySoundsToFavorites 2"
            ])
            XCTAssertEqual(response.total_views, 27)
        }
    }

    func testNavigationAnalyticsIsEmptyWithoutMetrics() async throws {
        try await app.test(.GET, "api/v3/navigation-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(NavigationAnalyticsResponse.self)
            XCTAssertTrue(response.top_screens.isEmpty)
            XCTAssertEqual(response.total_views, 0)
        }
    }

    // MARK: - version-signals-hourly

    func testVersionSignalsHourlyBreaksTheDayDownByHourAndVersion() async throws {
        try await signal("a", version: "13.8", at: "2026-10-01T09:05:00.000Z")
        try await signal("a", version: "13.8", at: "2026-10-01T09:35:00.000Z")
        try await signal("b", version: "13.8", at: "2026-10-01T09:40:00.000Z")
        try await signal("c", version: "13.7", at: "2026-10-01T09:50:00.000Z")
        try await signal("a", version: "13.8", at: "2026-10-01T23:10:00.000Z")
        try await signal("d", version: "13.6", at: "2026-10-01T00:00:00.000Z")
        try await signal("e", version: "13.8", at: "2026-10-02T00:00:00.000Z")
        try await signal("f", version: "13.8", at: "2026-09-30T23:59:59.999Z")

        try await app.test(.GET, "api/v4/version-signals-hourly/2026-10-01/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["date", "hours", "dayTotals"])
            let response = try res.content.decode(VersionSignalsHourlyResponse.self)
            XCTAssertEqual(response.date, "2026-10-01")
            XCTAssertEqual(response.hours.map(\.hour), Array(0...23))
            let nonEmpty = response.hours.filter { !$0.versions.isEmpty }
            XCTAssertEqual(nonEmpty.map { "\($0.hour): " + $0.versions.map { "\($0.appVersion) \($0.uniqueUsers)/\($0.signalCount)" }.joined(separator: ", ") }, [
                "0: 13.6 1/1",
                "9: 13.8 2/3, 13.7 1/1",
                "23: 13.8 1/1"
            ])
            let totals = response.dayTotals.map { "\($0.appVersion) \($0.uniqueUsers) \($0.percentage)" }
            XCTAssertEqual(totals.first, "13.8 2 50.0")
            XCTAssertEqual(Set(totals.dropFirst()), ["13.6 1 25.0", "13.7 1 25.0"])
        }
    }

    func testVersionSignalsHourlyRoundsPercentagesToOneDecimal() async throws {
        try await signal("a", version: "13.8", at: "2026-10-01T10:00:00.000Z")
        try await signal("b", version: "13.8", at: "2026-10-01T10:00:00.000Z")
        try await signal("c", version: "13.7", at: "2026-10-01T10:00:00.000Z")

        try await app.test(.GET, "api/v4/version-signals-hourly/2026-10-01/\(TestEnvironment.testPassword)") { res async throws in
            let response = try res.content.decode(VersionSignalsHourlyResponse.self)
            XCTAssertEqual(response.dayTotals.map(\.percentage), [66.7, 33.3])
        }
    }

    func testVersionSignalsHourlyRejectsABadDate() async throws {
        for date in ["2026-10-1", "01-10-2026", "2026-10-01'%20OR%20'1'='1", "yesterday"] {
            try await app.test(.GET, "api/v4/version-signals-hourly/\(date)/\(TestEnvironment.testPassword)") { res async in
                XCTAssertEqual(res.status, .badRequest, date)
            }
        }
    }

    func testVersionSignalsHourlyIsEmptyForADayWithoutSignals() async throws {
        try await app.test(.GET, "api/v4/version-signals-hourly/2026-10-01/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(VersionSignalsHourlyResponse.self)
            XCTAssertEqual(response.hours.count, 24)
            XCTAssertTrue(response.hours.allSatisfy { $0.versions.isEmpty })
            XCTAssertTrue(response.dayTotals.isEmpty)
        }
    }

    // MARK: - version-adoption-daily

    func testVersionAdoptionDailyCoversTodayAndTheLastNDays() async throws {
        try await signal("a", version: "13.8", at: "\(utcDay(0))T00:30:00.000Z")
        try await signal("b", version: "13.8", at: "\(utcDay(0))T00:31:00.000Z")
        try await signal("c", version: "13.7", at: "\(utcDay(0))T00:32:00.000Z")
        try await signal("a", version: "13.7", at: "\(utcDay(1))T12:00:00.000Z")
        try await signal("d", version: "13.6", at: "\(utcDay(3))T00:00:00.000Z")
        try await signal("e", version: "13.5", at: "\(utcDay(4))T23:59:59.999Z")

        try await app.test(.GET, "api/v4/version-adoption-daily/3/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["days", "data"])
            let response = try res.content.decode(VersionAdoptionDailyResponse.self)
            XCTAssertEqual(response.days, 3)
            // Days without signals are left out, not zero-filled.
            XCTAssertEqual(response.data.map { "\($0.date): " + $0.versions.map { "\($0.appVersion) \($0.uniqueUsers)" }.joined(separator: ", ") }, [
                "\(utcDay(3)): 13.6 1",
                "\(utcDay(1)): 13.7 1",
                "\(utcDay(0)): 13.8 2, 13.7 1"
            ])
        }
    }

    func testVersionAdoptionDailyRejectsBadDays() async throws {
        for days in ["0", "366", "-1", "week", "3%20days"] {
            try await app.test(.GET, "api/v4/version-adoption-daily/\(days)/\(TestEnvironment.testPassword)") { res async in
                XCTAssertEqual(res.status, .badRequest, days)
            }
        }
        try await app.test(.GET, "api/v4/version-adoption-daily/365/\(TestEnvironment.testPassword)") { res async in
            XCTAssertEqual(res.status, .ok)
        }
    }

    // MARK: - version-distribution

    func testVersionDistributionCoversTodayInUTC() async throws {
        try await signal("a", version: "13.8", at: "\(utcDay(0))T00:30:00.000Z")
        try await signal("a", version: "13.8", at: "\(utcDay(0))T00:40:00.000Z")
        try await signal("b", version: "13.8", at: "\(utcDay(0))T00:31:00.000Z")
        try await signal("c", version: "13.8", at: "\(utcDay(0))T00:32:00.000Z")
        try await signal("d", version: "13.7", at: "\(utcDay(0))T00:33:00.000Z")
        try await signal("e", version: "13.6", at: "\(utcDay(1))T23:59:59.999Z")

        try await app.test(.GET, "api/v4/version-distribution/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["date", "versions", "totalUsers"])
            let response = try res.content.decode(VersionDistributionResponse.self)
            XCTAssertEqual(response.date, self.utcDay(0))
            XCTAssertEqual(response.versions.map { "\($0.appVersion) \($0.uniqueUsers) \($0.percentage)" }, [
                "13.8 3 75.0", "13.7 1 25.0"
            ])
            XCTAssertEqual(response.totalUsers, 4)
        }
    }

    func testVersionDistributionIsEmptyWithoutSignalsToday() async throws {
        try await app.test(.GET, "api/v4/version-distribution/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(VersionDistributionResponse.self)
            XCTAssertEqual(response.date, self.utcDay(0))
            XCTAssertTrue(response.versions.isEmpty)
            XCTAssertEqual(response.totalUsers, 0)
        }
    }

    // MARK: - Passwords

    func testEveryRouteRejectsAWrongPassword() async throws {
        let paths = [
            "api/v3/navigation-analytics/wrong",
            "api/v4/version-signals-hourly/2026-10-01/wrong",
            "api/v4/version-adoption-daily/7/wrong",
            "api/v4/version-distribution/wrong"
        ]
        for path in paths {
            try await app.test(.GET, path) { res async in
                XCTAssertEqual(res.status, .forbidden, path)
            }
        }
    }
}
