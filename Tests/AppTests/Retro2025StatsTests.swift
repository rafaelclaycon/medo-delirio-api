@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

/// The Retro 2025 routes are commented out in `routes.swift` until Retro 2026, so these
/// tests register the same paths themselves.
struct Retro2025StatsTests {

    /// A fresh app with the Retro 2025 routes registered.
    private func withRetroRoutes(_ test: (Application) async throws -> Void) async throws {
        try await withTestApp { app in
            let statisticsController = StatisticsController()
            app.get("api", "v4", "retro2025-share-count", ":date", use: statisticsController.getRetro2025ShareCountHandlerV4)
            app.get("api", "v4", "retro2025-dashboard", ":date", use: statisticsController.getRetro2025DashboardHandlerV4)
            app.get("api", "v4", "retro2025-top-sounds", ":date", use: statisticsController.getRetro2025TopSoundsHandlerV4)
            app.get("api", "v4", "retro2025-top-authors", ":date", use: statisticsController.getRetro2025TopAuthorsHandlerV4)
            app.get("api", "v4", "retro2025-day-patterns", ":date", use: statisticsController.getRetro2025DayPatternsHandlerV4)
            app.get("api", "v4", "retro2025-user-stats", ":date", use: statisticsController.getRetro2025UserStatsHandlerV4)
            app.get("api", "v4", "retro2025-dashboard-range", ":startDate", ":endDate", use: statisticsController.getRetro2025DashboardRangeHandlerV4)
            app.get("api", "v4", "retro2025-top-sounds-range", ":startDate", ":endDate", use: statisticsController.getRetro2025TopSoundsRangeHandlerV4)
            app.get("api", "v4", "retro2025-top-authors-range", ":startDate", ":endDate", use: statisticsController.getRetro2025TopAuthorsRangeHandlerV4)
            app.get("api", "v4", "retro2025-day-patterns-range", ":startDate", ":endDate", use: statisticsController.getRetro2025DayPatternsRangeHandlerV4)
            app.get("api", "v4", "retro2025-user-stats-range", ":startDate", ":endDate", use: statisticsController.getRetro2025UserStatsRangeHandlerV4)
            try await test(app)
        }
    }

    private func share(_ destination: String, install: String, from origin: String = "Retro2025", at dateTime: String, on app: Application) async throws {
        try await UsageMetric(
            customInstallId: install, originatingScreen: origin, destinationScreen: destination,
            systemName: "iOS", isiOSAppOnMac: false, appVersion: "13.8",
            dateTime: dateTime, currentTimeZone: "America/Sao_Paulo"
        ).save(on: app.db)
    }

    /// Six shares on 10 December, one on the 11th and one that isn't a Retro share.
    private func seed(on app: Application) async throws {
        let day = "2025-12-10T15:00:00.000Z"
        try await share("1 Fala, 2 Risada, 3 Grito; 100 compart; Segunda; Bolsonaro; https://img/b.jpg", install: "a", at: day, on: app)
        try await share("1 Fala, 4 Choro; 20 compart; Segunda; Bolsonaro", install: "a", at: day, on: app)
        try await share("1 Fala, 2 Risada; 5 compart; Segunda; Lula; https://img/l.jpg", install: "b", at: day, on: app)
        try await share("2 Risada; 1 compart; Terça", install: "b", at: day, on: app)
        try await share("3 Grito; 1 compart; Terça", install: "b", at: day, on: app)
        try await share("1 Fala", install: "c", at: day, on: app)
        try await share("5 Outro; 50 compart; Quarta; Ciro", install: "d", at: "2025-12-11T10:00:00.000Z", on: app)
        try await share("1 Fala; 999 compart; Segunda; Bolsonaro", install: "e", from: "SoundsTab", at: day, on: app)
    }

    private func jsonObject(_ res: TestingHTTPResponse) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
    }

    // MARK: - Share count

    @Test func `Share count counts distinct installs that shared their Retro`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)

            try await app.testing().test(.GET, "api/v4/retro2025-share-count/2025-12-10") { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(Retro2025ShareCountResponse.self)
                #expect(response.shareCount == 3)
                #expect(response.date == "2025-12-10")
            }
        }
    }

    // MARK: - Daily

    @Test func `Dashboard for a day`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)

            try await app.testing().test(.GET, "api/v4/retro2025-dashboard/2025-12-10") { res async throws in
                #expect(res.status == .ok)
                let json = try self.jsonObject(res)
                // nil dates are left out of the JSON.
                #expect(Set(json.keys) == ["overallStats", "topSounds", "topAuthors", "dayPatterns", "topUsers", "date"])
                #expect(Set(try #require(json["overallStats"] as? [String: Any]).keys) == ["totalShares", "uniqueUsers", "averageSharesPerUser"])

                let response = try res.content.decode(Retro2025DashboardResponse.self)
                #expect(response.date == "2025-12-10")
                #expect(response.startDate == nil)
                #expect(response.endDate == nil)
                // A share without a "compart" segment counts as one.
                #expect(response.overallStats.totalShares == 128)
                #expect(response.overallStats.uniqueUsers == 3)
                #expect(abs(response.overallStats.averageSharesPerUser - (128.0 / 3.0)) <= 0.0001)

                #expect(response.topSounds.map { "\($0.soundNumber) \($0.soundName) \($0.shareCount)" } == [
                    "1 Fala 4", "2 Risada 3", "3 Grito 2", "4 Choro 1"
                ])
                #expect(response.topAuthors.map { "\($0.authorName) \($0.shareCount) \($0.imageURL ?? "nil")" } == [
                    "Bolsonaro 2 https://img/b.jpg", "Lula 1 https://img/l.jpg"
                ])
                #expect(response.dayPatterns.map { "\($0.dayName) \($0.shareCount)" } == ["Segunda 3", "Terça 2"])
                #expect(response.topUsers.map { "\($0.userId) \($0.totalShares) \($0.mostActiveDay ?? "nil")" } == [
                    "a 120 Segunda", "b 7 Terça", "c 1 nil"
                ])
            }
        }
    }

    @Test func `Each part of the dashboard has its own route`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)

            try await app.testing().test(.GET, "api/v4/retro2025-top-sounds/2025-12-10") { res async throws in
                #expect(try res.content.decode([Retro2025SoundStat].self).map { "\($0.soundNumber) \($0.soundName) \($0.shareCount)" } == [
                    "1 Fala 4", "2 Risada 3", "3 Grito 2", "4 Choro 1"
                ])
            }
            try await app.testing().test(.GET, "api/v4/retro2025-top-authors/2025-12-10") { res async throws in
                #expect(try res.content.decode([Retro2025AuthorStat].self).map { "\($0.authorName) \($0.shareCount) \($0.imageURL ?? "nil")" } == [
                    "Bolsonaro 2 https://img/b.jpg", "Lula 1 https://img/l.jpg"
                ])
            }
            try await app.testing().test(.GET, "api/v4/retro2025-day-patterns/2025-12-10") { res async throws in
                #expect(try res.content.decode([Retro2025DayOfWeekStat].self).map { "\($0.dayName) \($0.shareCount)" } == ["Segunda 3", "Terça 2"])
            }
            try await app.testing().test(.GET, "api/v4/retro2025-user-stats/2025-12-10") { res async throws in
                #expect(try res.content.decode([Retro2025UserStat].self).map { "\($0.userId) \($0.totalShares) \($0.mostActiveDay ?? "nil")" } == [
                    "a 120 Segunda", "b 7 Terça", "c 1 nil"
                ])
            }
        }
    }

    /// The dashboard keeps the top 10; the separate routes return everything.
    @Test func `Only the dashboard keeps the top 10`() async throws {
        try await withRetroRoutes { app in
            for i in 1...12 {
                let sounds = (1...i).map { "\($0) Som \($0)" }.joined(separator: ", ")
                try await share("\(sounds); 1 compart; Segunda; Autor \(i)", install: "user-\(i)", at: "2025-12-10T15:00:00.000Z", on: app)
            }
            for _ in 1...12 {
                try await share("1 Som 1; \(12) compart; Terça", install: "user-12", at: "2025-12-10T16:00:00.000Z", on: app)
            }

            try await app.testing().test(.GET, "api/v4/retro2025-dashboard/2025-12-10") { res async throws in
                let response = try res.content.decode(Retro2025DashboardResponse.self)
                #expect(response.topSounds.map(\.soundNumber) == Array(1...10))
                #expect(response.topSounds.first?.shareCount == 24)
                #expect(response.topAuthors.count == 10)
                #expect(response.topUsers.count == 10)
                #expect(response.topUsers.first?.userId == "user-12")
                #expect(response.topUsers.first?.mostActiveDay == "Terça")
            }
            try await app.testing().test(.GET, "api/v4/retro2025-top-sounds/2025-12-10") { res async throws in
                #expect(try res.content.decode([Retro2025SoundStat].self).map(\.soundNumber) == Array(1...12))
            }
            try await app.testing().test(.GET, "api/v4/retro2025-top-authors/2025-12-10") { res async throws in
                #expect(try res.content.decode([Retro2025AuthorStat].self).count == 12)
            }
            try await app.testing().test(.GET, "api/v4/retro2025-user-stats/2025-12-10") { res async throws in
                #expect(try res.content.decode([Retro2025UserStat].self).count == 12)
            }
        }
    }

    @Test func `A day without shares is empty`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)

            try await app.testing().test(.GET, "api/v4/retro2025-dashboard/2025-12-25") { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(Retro2025DashboardResponse.self)
                #expect(response.overallStats.totalShares == 0)
                #expect(response.overallStats.uniqueUsers == 0)
                #expect(response.overallStats.averageSharesPerUser == 0)
                #expect(response.topSounds.isEmpty)
                #expect(response.topUsers.isEmpty)
            }
        }
    }

    // MARK: - Date range

    @Test func `Dashboard for a range includes both ends`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)
            try await share("9 Fora; 1000 compart; Quinta; Ninguém", install: "z", at: "2025-12-12T00:00:00.000Z", on: app)
            try await share("9 Fora; 1000 compart; Quinta; Ninguém", install: "z", at: "2025-12-09T23:59:59.999Z", on: app)

            try await app.testing().test(.GET, "api/v4/retro2025-dashboard-range/2025-12-10/2025-12-11") { res async throws in
                #expect(res.status == .ok)
                let json = try self.jsonObject(res)
                #expect(Set(json.keys) == ["overallStats", "topSounds", "topAuthors", "dayPatterns", "topUsers", "startDate", "endDate"])

                let response = try res.content.decode(Retro2025DashboardResponse.self)
                #expect(response.date == nil)
                #expect(response.startDate == "2025-12-10")
                #expect(response.endDate == "2025-12-11")
                #expect(response.overallStats.startDate == "2025-12-10")
                #expect(response.overallStats.endDate == "2025-12-11")
                #expect(response.overallStats.totalShares == 178)
                #expect(response.overallStats.uniqueUsers == 4)
                #expect(response.topUsers.map { "\($0.userId) \($0.totalShares)" } == ["a 120", "d 50", "b 7", "c 1"])
                #expect(response.dayPatterns.map { "\($0.dayName) \($0.shareCount)" } == ["Segunda 3", "Terça 2", "Quarta 1"])
            }
        }
    }

    @Test func `Each part of the dashboard has a range route`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)

            try await app.testing().test(.GET, "api/v4/retro2025-top-sounds-range/2025-12-10/2025-12-11") { res async throws in
                let sounds = try res.content.decode([Retro2025SoundStat].self)
                #expect(sounds.prefix(3).map { "\($0.soundNumber) \($0.shareCount)" } == ["1 4", "2 3", "3 2"])
                #expect(Set(sounds.dropFirst(3).map(\.soundName)) == ["Choro", "Outro"])
            }
            try await app.testing().test(.GET, "api/v4/retro2025-top-authors-range/2025-12-10/2025-12-11") { res async throws in
                let authors = try res.content.decode([Retro2025AuthorStat].self)
                #expect(authors.first?.authorName == "Bolsonaro")
                #expect(Set(authors.dropFirst().map(\.authorName)) == ["Lula", "Ciro"])
            }
            try await app.testing().test(.GET, "api/v4/retro2025-day-patterns-range/2025-12-10/2025-12-11") { res async throws in
                #expect(try res.content.decode([Retro2025DayOfWeekStat].self).map(\.dayName) == ["Segunda", "Terça", "Quarta"])
            }
            try await app.testing().test(.GET, "api/v4/retro2025-user-stats-range/2025-12-10/2025-12-11") { res async throws in
                #expect(try res.content.decode([Retro2025UserStat].self).map(\.userId) == ["a", "d", "b", "c"])
            }
        }
    }

    // MARK: - Dates are values, not SQL

    @Test func `A date can't change the query`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)
            let injected = "2099-01-01')%20OR%201=1%20OR%20date('"

            try await app.testing().test(.GET, "api/v4/retro2025-dashboard/\(injected)") { res async throws in
                let response = try res.content.decode(Retro2025DashboardResponse.self)
                #expect(response.overallStats.totalShares == 0)
            }
            try await app.testing().test(.GET, "api/v4/retro2025-user-stats-range/\(injected)/2099-01-02") { res async throws in
                #expect(try res.content.decode([Retro2025UserStat].self).count == 0)
            }
            try await app.testing().test(.GET, "api/v4/retro2025-top-sounds-range/2099-01-01/\(injected)") { res async throws in
                #expect(try res.content.decode([Retro2025SoundStat].self).count == 0)
            }
        }
    }

    /// A range whose ends are the same day reads like the daily route.
    @Test func `A range of one day looks like a day`() async throws {
        try await withRetroRoutes { app in
            try await seed(on: app)

            try await app.testing().test(.GET, "api/v4/retro2025-dashboard-range/2025-12-10/2025-12-10") { res async throws in
                let response = try res.content.decode(Retro2025DashboardResponse.self)
                #expect(response.date == "2025-12-10")
                #expect(response.startDate == nil)
                #expect(response.endDate == nil)
                #expect(response.overallStats.totalShares == 128)
            }
        }
    }
}
