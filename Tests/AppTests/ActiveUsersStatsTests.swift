@testable import App
import XCTVapor
import Fluent
import Foundation

final class ActiveUsersStatsTests: XCTestCase {
    var app: Application!

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

    private func jsonObject(_ res: XCTHTTPResponse) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView))
    }

    func testActiveUsersCountsDistinctInstallsSinceTheDate() async throws {
        try await signal("install-1", at: "2026-10-01T10:00:00.000Z")
        try await signal("install-1", at: "2026-10-02T10:00:00.000Z")
        try await signal("install-2", at: "2026-10-03T10:00:00.000Z")
        try await signal("install-3", at: "2026-09-30T23:59:59.999Z")

        try await app.test(.GET, "api/v3/active-users-count-from/2026-10-01/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["activeUsers", "date"])
            XCTAssertEqual(json["activeUsers"] as? Int, 2)
            XCTAssertEqual(json["date"] as? String, "2026-10-01")
        }
    }

    func testSessionsCountsEverySignalSinceTheDate() async throws {
        try await signal("install-1", at: "2026-10-01T10:00:00.000Z")
        try await signal("install-1", at: "2026-10-02T10:00:00.000Z")
        try await signal("install-2", at: "2026-10-03T10:00:00.000Z")
        try await signal("install-3", at: "2026-09-30T23:59:59.999Z")

        try await app.test(.GET, "api/v3/sessions-count-from/2026-10-01/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["sessionsCount", "date"])
            XCTAssertEqual(json["sessionsCount"] as? Int, 3)
            XCTAssertEqual(json["date"] as? String, "2026-10-01")
        }
    }

    func testDailyActiveUsersCoversTheLast30DaysOldestFirst() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let now = Date()
        let today = formatter.string(from: now)
        let yesterday = formatter.string(from: now.addingTimeInterval(-24 * 60 * 60))

        try await signal("install-1", at: now.iso8601withFractionalSeconds)
        try await signal("install-1", at: now.iso8601withFractionalSeconds)
        try await signal("install-2", at: now.iso8601withFractionalSeconds)
        try await signal("install-3", at: "\(yesterday)T12:00:00.000Z")
        try await signal("install-4", at: now.addingTimeInterval(-40 * 24 * 60 * 60).iso8601withFractionalSeconds)

        try await app.test(.GET, "api/v3/active-users-daily-last-30-days/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(try self.jsonObject(res) as? [[String: Any]])
            XCTAssertEqual(list.count, 30)
            XCTAssertEqual(Set(try XCTUnwrap(list.first).keys), ["date", "activeUsers"])
            let dates = list.compactMap { $0["date"] as? String }
            XCTAssertEqual(dates, dates.sorted())
            XCTAssertEqual(Set(dates).count, 30)
            XCTAssertEqual(dates.last, today)
            XCTAssertEqual(dates.dropLast().last, yesterday)
            let counts = list.compactMap { $0["activeUsers"] as? Int }
            XCTAssertEqual(counts.last, 2)
            XCTAssertEqual(counts.dropLast().last, 1)
            XCTAssertEqual(counts.reduce(0, +), 3)
        }
    }

    func testEveryEndpointRejectsAWrongPassword() async throws {
        for path in [
            "api/v3/active-users-count-from/2026-10-01/wrong",
            "api/v3/sessions-count-from/2026-10-01/wrong",
            "api/v3/active-users-daily-last-30-days/wrong",
        ] {
            try await app.test(.GET, path) { res async in
                XCTAssertEqual(res.status, .forbidden, path)
            }
        }
    }
}
