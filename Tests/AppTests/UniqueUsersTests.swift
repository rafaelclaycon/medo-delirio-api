@testable import App
import XCTVapor
import Fluent
import FluentSQLiteDriver
import Foundation

final class UniqueUsersTests: XCTestCase {

    var app: Application!

    /// 15:00 UTC on 1 November 2026.
    private let now = Date(timeIntervalSince1970: 1_793_545_200)

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func signal(_ installId: String, at dateTime: String) async throws {
        try await StillAliveSignal(
            installId: installId, modelName: "iPhone17,1", systemName: "iOS", systemVersion: "26.0",
            isiOSAppOnMac: false, appVersion: "13.8", currentTimeZone: "America/Sao_Paulo", dateTime: dateTime
        ).save(on: app.db)
    }

    func testCountsDistinctInstallsPerRollingWindow() async throws {
        try await signal("ancient", at: "2023-01-10T12:00:00.000Z")
        try await signal("month", at: "2026-10-03T15:00:00.000Z")
        try await signal("tooOldForMonth", at: "2026-10-02T14:59:59.000Z")
        try await signal("week", at: "2026-10-25T15:00:00.000Z")
        try await signal("week", at: "2026-10-31T09:00:00.000Z")
        try await signal("tooOldForWeek", at: "2026-10-25T14:59:59.000Z")
        try await signal("today", at: "2026-11-01T14:00:00.000Z")
        try await signal("ancient", at: "2026-11-01T14:30:00.000Z")

        let sqlite = try XCTUnwrap(app.db as? SQLiteDatabase)
        let users = try await StatisticsController.uniqueUsers(on: sqlite, now: now)

        XCTAssertEqual(users.lastWeek, 3)
        XCTAssertEqual(users.lastMonth, 5)
        XCTAssertEqual(users.allTime, 6)
    }

    func testRouteNeedsThePassword() async throws {
        try await app.test(.GET, "api/v4/unique-users/wrong") { res async in
            XCTAssertEqual(res.status, .forbidden)
        }
        try await app.test(.GET, "api/v4/unique-users/\(TestEnvironment.testPassword)") { res async in
            XCTAssertEqual(res.status, .ok)
        }
    }
}
