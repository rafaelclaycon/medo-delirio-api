@testable import App
import Testing
import VaporTesting
import Fluent
import FluentSQLiteDriver
import Foundation

struct UniqueUsersTests {

    /// 15:00 UTC on 1 November 2026.
    private let now = Date(timeIntervalSince1970: 1_793_545_200)

    private func signal(_ installId: String, at dateTime: String, on app: Application) async throws {
        try await StillAliveSignal(
            installId: installId, modelName: "iPhone17,1", systemName: "iOS", systemVersion: "26.0",
            isiOSAppOnMac: false, appVersion: "13.8", currentTimeZone: "America/Sao_Paulo", dateTime: dateTime
        ).save(on: app.db)
    }

    @Test func `Counts distinct installs per rolling window`() async throws {
        try await withTestApp { app in
            try await signal("ancient", at: "2023-01-10T12:00:00.000Z", on: app)
            try await signal("month", at: "2026-10-03T15:00:00.000Z", on: app)
            try await signal("tooOldForMonth", at: "2026-10-02T14:59:59.000Z", on: app)
            try await signal("week", at: "2026-10-25T15:00:00.000Z", on: app)
            try await signal("week", at: "2026-10-31T09:00:00.000Z", on: app)
            try await signal("tooOldForWeek", at: "2026-10-25T14:59:59.000Z", on: app)
            try await signal("today", at: "2026-11-01T14:00:00.000Z", on: app)
            try await signal("ancient", at: "2026-11-01T14:30:00.000Z", on: app)

            let sqlite = try #require(app.db as? SQLiteDatabase)
            let users = try await StatisticsController.uniqueUsers(on: sqlite, now: now)

            #expect(users.lastWeek == 3)
            #expect(users.lastMonth == 5)
            #expect(users.allTime == 6)
        }
    }

    @Test func `Route needs the password`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v4/unique-users/wrong") { res async in
                #expect(res.status == .forbidden)
            }
            try await app.testing().test(.GET, "api/v4/unique-users/\(TestEnvironment.testPassword)") { res async in
                #expect(res.status == .ok)
            }
        }
    }
}
