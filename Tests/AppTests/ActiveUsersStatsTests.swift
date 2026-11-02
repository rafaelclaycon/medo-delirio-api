@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct ActiveUsersStatsTests {

    private func signal(_ installId: String, at dateTime: String, on app: Application) async throws {
        try await StillAliveSignal(
            installId: installId, modelName: "iPhone17,1", systemName: "iOS", systemVersion: "26.0",
            isiOSAppOnMac: false, appVersion: "13.8", currentTimeZone: "America/Sao_Paulo", dateTime: dateTime
        ).save(on: app.db)
    }

    private func jsonObject(_ res: TestingHTTPResponse) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView))
    }

    @Test func `Active users counts distinct installs since the date`() async throws {
        try await withTestApp { app in
            try await signal("install-1", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("install-1", at: "2026-10-02T10:00:00.000Z", on: app)
            try await signal("install-2", at: "2026-10-03T10:00:00.000Z", on: app)
            try await signal("install-3", at: "2026-09-30T23:59:59.999Z", on: app)

            try await app.testing().test(.GET, "api/v3/active-users-count-from/2026-10-01/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let json = try #require(try self.jsonObject(res) as? [String: Any])
                #expect(Set(json.keys) == ["activeUsers", "date"])
                #expect(json["activeUsers"] as? Int == 2)
                #expect(json["date"] as? String == "2026-10-01")
            }
        }
    }

    @Test func `Sessions counts every signal since the date`() async throws {
        try await withTestApp { app in
            try await signal("install-1", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("install-1", at: "2026-10-02T10:00:00.000Z", on: app)
            try await signal("install-2", at: "2026-10-03T10:00:00.000Z", on: app)
            try await signal("install-3", at: "2026-09-30T23:59:59.999Z", on: app)

            try await app.testing().test(.GET, "api/v3/sessions-count-from/2026-10-01/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let json = try #require(try self.jsonObject(res) as? [String: Any])
                #expect(Set(json.keys) == ["sessionsCount", "date"])
                #expect(json["sessionsCount"] as? Int == 3)
                #expect(json["date"] as? String == "2026-10-01")
            }
        }
    }

    @Test func `Daily active users covers the last 30 days oldest first`() async throws {
        try await withTestApp { app in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let now = Date()
            let today = formatter.string(from: now)
            let yesterday = formatter.string(from: now.addingTimeInterval(-24 * 60 * 60))

            try await signal("install-1", at: now.iso8601withFractionalSeconds, on: app)
            try await signal("install-1", at: now.iso8601withFractionalSeconds, on: app)
            try await signal("install-2", at: now.iso8601withFractionalSeconds, on: app)
            try await signal("install-3", at: "\(yesterday)T12:00:00.000Z", on: app)
            try await signal("install-4", at: now.addingTimeInterval(-40 * 24 * 60 * 60).iso8601withFractionalSeconds, on: app)

            try await app.testing().test(.GET, "api/v3/active-users-daily-last-30-days/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(try self.jsonObject(res) as? [[String: Any]])
                #expect(list.count == 30)
                #expect(Set(try #require(list.first).keys) == ["date", "activeUsers"])
                let dates = list.compactMap { $0["date"] as? String }
                #expect(dates == dates.sorted())
                #expect(Set(dates).count == 30)
                #expect(dates.last == today)
                #expect(dates.dropLast().last == yesterday)
                let counts = list.compactMap { $0["activeUsers"] as? Int }
                #expect(counts.last == 2)
                #expect(counts.dropLast().last == 1)
                #expect(counts.reduce(0, +) == 3)
            }
        }
    }

    @Test func `A date can't change the query`() async throws {
        try await withTestApp { app in
            try await signal("install-1", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("install-2", at: "2026-10-02T10:00:00.000Z", on: app)
            // Spliced into the SQL, this would read `>= '2099-01-01' OR '1'='1'` and count everything.
            let date = "2099-01-01' OR '1'='1"
            let encoded = date.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!

            try await app.testing().test(.GET, "api/v3/active-users-count-from/\(encoded)/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(ActiveUsersResponse.self).activeUsers == 0)
            }
            try await app.testing().test(.GET, "api/v3/sessions-count-from/\(encoded)/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(SessionsResponse.self).sessionsCount == 0)
            }
        }
    }

    @Test(arguments: [
        "api/v3/active-users-count-from/2026-10-01/wrong",
        "api/v3/sessions-count-from/2026-10-01/wrong",
        "api/v3/active-users-daily-last-30-days/wrong",
    ])
    func `Every endpoint rejects a wrong password`(path: String) async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, path) { res async in
                #expect(res.status == .forbidden)
            }
        }
    }
}
