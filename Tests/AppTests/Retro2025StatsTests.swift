@testable import App
import XCTVapor
import Fluent
import Foundation

/// The Retro 2025 routes are commented out in `routes.swift` until Retro 2026, so these
/// tests register the same paths themselves.
final class Retro2025StatsTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)

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
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func share(_ destination: String, install: String, from origin: String = "Retro2025", at dateTime: String) async throws {
        try await UsageMetric(
            customInstallId: install, originatingScreen: origin, destinationScreen: destination,
            systemName: "iOS", isiOSAppOnMac: false, appVersion: "13.8",
            dateTime: dateTime, currentTimeZone: "America/Sao_Paulo"
        ).save(on: app.db)
    }

    /// Six shares on 10 December, one on the 11th and one that isn't a Retro share.
    private func seed() async throws {
        let day = "2025-12-10T15:00:00.000Z"
        try await share("1 Fala, 2 Risada, 3 Grito; 100 compart; Segunda; Bolsonaro; https://img/b.jpg", install: "a", at: day)
        try await share("1 Fala, 4 Choro; 20 compart; Segunda; Bolsonaro", install: "a", at: day)
        try await share("1 Fala, 2 Risada; 5 compart; Segunda; Lula; https://img/l.jpg", install: "b", at: day)
        try await share("2 Risada; 1 compart; Terça", install: "b", at: day)
        try await share("3 Grito; 1 compart; Terça", install: "b", at: day)
        try await share("1 Fala", install: "c", at: day)
        try await share("5 Outro; 50 compart; Quarta; Ciro", install: "d", at: "2025-12-11T10:00:00.000Z")
        try await share("1 Fala; 999 compart; Segunda; Bolsonaro", install: "e", from: "SoundsTab", at: day)
    }

    private func jsonObject(_ res: XCTHTTPResponse) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
    }

    // MARK: - Share count

    func testShareCountCountsDistinctInstallsThatSharedTheirRetro() async throws {
        try await seed()

        try await app.test(.GET, "api/v4/retro2025-share-count/2025-12-10") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(Retro2025ShareCountResponse.self)
            XCTAssertEqual(response.shareCount, 3)
            XCTAssertEqual(response.date, "2025-12-10")
        }
    }

    // MARK: - Daily

    func testDashboardForADay() async throws {
        try await seed()

        try await app.test(.GET, "api/v4/retro2025-dashboard/2025-12-10") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try self.jsonObject(res)
            // nil dates are left out of the JSON.
            XCTAssertEqual(Set(json.keys), ["overallStats", "topSounds", "topAuthors", "dayPatterns", "topUsers", "date"])
            XCTAssertEqual(Set(try XCTUnwrap(json["overallStats"] as? [String: Any]).keys), ["totalShares", "uniqueUsers", "averageSharesPerUser"])

            let response = try res.content.decode(Retro2025DashboardResponse.self)
            XCTAssertEqual(response.date, "2025-12-10")
            XCTAssertNil(response.startDate)
            XCTAssertNil(response.endDate)
            // A share without a "compart" segment counts as one.
            XCTAssertEqual(response.overallStats.totalShares, 128)
            XCTAssertEqual(response.overallStats.uniqueUsers, 3)
            XCTAssertEqual(response.overallStats.averageSharesPerUser, 128.0 / 3.0, accuracy: 0.0001)

            XCTAssertEqual(response.topSounds.map { "\($0.soundNumber) \($0.soundName) \($0.shareCount)" }, [
                "1 Fala 4", "2 Risada 3", "3 Grito 2", "4 Choro 1"
            ])
            XCTAssertEqual(response.topAuthors.map { "\($0.authorName) \($0.shareCount) \($0.imageURL ?? "nil")" }, [
                "Bolsonaro 2 https://img/b.jpg", "Lula 1 https://img/l.jpg"
            ])
            XCTAssertEqual(response.dayPatterns.map { "\($0.dayName) \($0.shareCount)" }, ["Segunda 3", "Terça 2"])
            XCTAssertEqual(response.topUsers.map { "\($0.userId) \($0.totalShares) \($0.mostActiveDay ?? "nil")" }, [
                "a 120 Segunda", "b 7 Terça", "c 1 nil"
            ])
        }
    }

    func testEachPartOfTheDashboardHasItsOwnRoute() async throws {
        try await seed()

        try await app.test(.GET, "api/v4/retro2025-top-sounds/2025-12-10") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025SoundStat].self).map { "\($0.soundNumber) \($0.soundName) \($0.shareCount)" }, [
                "1 Fala 4", "2 Risada 3", "3 Grito 2", "4 Choro 1"
            ])
        }
        try await app.test(.GET, "api/v4/retro2025-top-authors/2025-12-10") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025AuthorStat].self).map { "\($0.authorName) \($0.shareCount) \($0.imageURL ?? "nil")" }, [
                "Bolsonaro 2 https://img/b.jpg", "Lula 1 https://img/l.jpg"
            ])
        }
        try await app.test(.GET, "api/v4/retro2025-day-patterns/2025-12-10") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025DayOfWeekStat].self).map { "\($0.dayName) \($0.shareCount)" }, ["Segunda 3", "Terça 2"])
        }
        try await app.test(.GET, "api/v4/retro2025-user-stats/2025-12-10") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025UserStat].self).map { "\($0.userId) \($0.totalShares) \($0.mostActiveDay ?? "nil")" }, [
                "a 120 Segunda", "b 7 Terça", "c 1 nil"
            ])
        }
    }

    /// The dashboard keeps the top 10; the separate routes return everything.
    func testOnlyTheDashboardKeepsTheTop10() async throws {
        for i in 1...12 {
            let sounds = (1...i).map { "\($0) Som \($0)" }.joined(separator: ", ")
            try await share("\(sounds); 1 compart; Segunda; Autor \(i)", install: "user-\(i)", at: "2025-12-10T15:00:00.000Z")
        }
        for _ in 1...12 {
            try await share("1 Som 1; \(12) compart; Terça", install: "user-12", at: "2025-12-10T16:00:00.000Z")
        }

        try await app.test(.GET, "api/v4/retro2025-dashboard/2025-12-10") { res async throws in
            let response = try res.content.decode(Retro2025DashboardResponse.self)
            XCTAssertEqual(response.topSounds.map(\.soundNumber), Array(1...10))
            XCTAssertEqual(response.topSounds.first?.shareCount, 24)
            XCTAssertEqual(response.topAuthors.count, 10)
            XCTAssertEqual(response.topUsers.count, 10)
            XCTAssertEqual(response.topUsers.first?.userId, "user-12")
            XCTAssertEqual(response.topUsers.first?.mostActiveDay, "Terça")
        }
        try await app.test(.GET, "api/v4/retro2025-top-sounds/2025-12-10") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025SoundStat].self).map(\.soundNumber), Array(1...12))
        }
        try await app.test(.GET, "api/v4/retro2025-top-authors/2025-12-10") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025AuthorStat].self).count, 12)
        }
        try await app.test(.GET, "api/v4/retro2025-user-stats/2025-12-10") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025UserStat].self).count, 12)
        }
    }

    func testADayWithoutSharesIsEmpty() async throws {
        try await seed()

        try await app.test(.GET, "api/v4/retro2025-dashboard/2025-12-25") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(Retro2025DashboardResponse.self)
            XCTAssertEqual(response.overallStats.totalShares, 0)
            XCTAssertEqual(response.overallStats.uniqueUsers, 0)
            XCTAssertEqual(response.overallStats.averageSharesPerUser, 0)
            XCTAssertTrue(response.topSounds.isEmpty)
            XCTAssertTrue(response.topUsers.isEmpty)
        }
    }

    // MARK: - Date range

    func testDashboardForARangeIncludesBothEnds() async throws {
        try await seed()
        try await share("9 Fora; 1000 compart; Quinta; Ninguém", install: "z", at: "2025-12-12T00:00:00.000Z")
        try await share("9 Fora; 1000 compart; Quinta; Ninguém", install: "z", at: "2025-12-09T23:59:59.999Z")

        try await app.test(.GET, "api/v4/retro2025-dashboard-range/2025-12-10/2025-12-11") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try self.jsonObject(res)
            XCTAssertEqual(Set(json.keys), ["overallStats", "topSounds", "topAuthors", "dayPatterns", "topUsers", "startDate", "endDate"])

            let response = try res.content.decode(Retro2025DashboardResponse.self)
            XCTAssertNil(response.date)
            XCTAssertEqual(response.startDate, "2025-12-10")
            XCTAssertEqual(response.endDate, "2025-12-11")
            XCTAssertEqual(response.overallStats.startDate, "2025-12-10")
            XCTAssertEqual(response.overallStats.endDate, "2025-12-11")
            XCTAssertEqual(response.overallStats.totalShares, 178)
            XCTAssertEqual(response.overallStats.uniqueUsers, 4)
            XCTAssertEqual(response.topUsers.map { "\($0.userId) \($0.totalShares)" }, ["a 120", "d 50", "b 7", "c 1"])
            XCTAssertEqual(response.dayPatterns.map { "\($0.dayName) \($0.shareCount)" }, ["Segunda 3", "Terça 2", "Quarta 1"])
        }
    }

    func testEachPartOfTheDashboardHasARangeRoute() async throws {
        try await seed()

        try await app.test(.GET, "api/v4/retro2025-top-sounds-range/2025-12-10/2025-12-11") { res async throws in
            let sounds = try res.content.decode([Retro2025SoundStat].self)
            XCTAssertEqual(sounds.prefix(3).map { "\($0.soundNumber) \($0.shareCount)" }, ["1 4", "2 3", "3 2"])
            XCTAssertEqual(Set(sounds.dropFirst(3).map(\.soundName)), ["Choro", "Outro"])
        }
        try await app.test(.GET, "api/v4/retro2025-top-authors-range/2025-12-10/2025-12-11") { res async throws in
            let authors = try res.content.decode([Retro2025AuthorStat].self)
            XCTAssertEqual(authors.first?.authorName, "Bolsonaro")
            XCTAssertEqual(Set(authors.dropFirst().map(\.authorName)), ["Lula", "Ciro"])
        }
        try await app.test(.GET, "api/v4/retro2025-day-patterns-range/2025-12-10/2025-12-11") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025DayOfWeekStat].self).map(\.dayName), ["Segunda", "Terça", "Quarta"])
        }
        try await app.test(.GET, "api/v4/retro2025-user-stats-range/2025-12-10/2025-12-11") { res async throws in
            XCTAssertEqual(try res.content.decode([Retro2025UserStat].self).map(\.userId), ["a", "d", "b", "c"])
        }
    }

    /// A range whose ends are the same day reads like the daily route.
    func testARangeOfOneDayLooksLikeADay() async throws {
        try await seed()

        try await app.test(.GET, "api/v4/retro2025-dashboard-range/2025-12-10/2025-12-10") { res async throws in
            let response = try res.content.decode(Retro2025DashboardResponse.self)
            XCTAssertEqual(response.date, "2025-12-10")
            XCTAssertNil(response.startDate)
            XCTAssertNil(response.endDate)
            XCTAssertEqual(response.overallStats.totalShares, 128)
        }
    }
}
