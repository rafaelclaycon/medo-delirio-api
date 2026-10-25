import Vapor
import Fluent
import FluentSQLiteDriver

struct WidgetSummaryResponse: Content, Equatable {

    /// Distinct installs today, over all of yesterday, and yesterday up to the same time
    /// of day as now, which is what a day still in progress compares fairly against.
    struct DayComparison: Content, Equatable {
        let today: Int
        let yesterday: Int
        let yesterdayUntilNow: Int
    }

    struct TopVersion: Content, Equatable {
        let appVersion: String
        let uniqueUsers: Int
        /// Share of today's users, 0–100, one decimal.
        let percentage: Double
    }

    /// The UTC day the numbers are for, "yyyy-MM-dd", like the rest of the analytics.
    let day: String
    let activeUsers: DayComparison
    let chapterUsers: DayComparison
    /// Distinct installs that started a game today.
    let gamePlayers: Int
    let topVersion: TopVersion?
    let generatedAt: String
}

/// The four numbers on MedoHelper's Home Screen widget, in one small request: the other
/// endpoints return 30 days of detail, too much to fetch every few minutes. Each number
/// is counted like its screen in MedoHelper, so they match.
struct WidgetSummaryController {

    /// The UTC boundaries the counts use, as the ISO 8601 strings `dateTime` is stored as.
    struct Windows: Equatable {
        let day: String
        let yesterdayStart: String
        let todayStart: String
        /// This time of day, yesterday.
        let yesterdayUntilNow: String

        init(now: Date) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
            let todayStart = calendar.startOfDay(for: now)
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            let yesterdayUntilNow = calendar.date(byAdding: .day, value: -1, to: now) ?? now

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            dayFormatter.timeZone = calendar.timeZone
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")

            self.day = dayFormatter.string(from: todayStart)
            self.yesterdayStart = yesterdayStart.iso8601withFractionalSeconds
            self.todayStart = todayStart.iso8601withFractionalSeconds
            self.yesterdayUntilNow = yesterdayUntilNow.iso8601withFractionalSeconds
        }
    }

    func getWidgetSummaryHandlerV4(req: Request) async throws -> WidgetSummaryResponse {
        guard req.parameters.get("password") == ReleaseConfigs.Passwords.analyticsPassword else {
            throw Abort(.forbidden)
        }
        guard let sqlite = req.db as? SQLiteDatabase else {
            throw Abort(.internalServerError, reason: "Database is not SQLite")
        }
        return try await Self.summary(on: sqlite, now: .now)
    }

    static func summary(on sqlite: SQLiteDatabase, now: Date) async throws -> WidgetSummaryResponse {
        let windows = Windows(now: now)

        // Like `active-users-daily-last-30-days`: every signal counts.
        let activeUsers = try await comparison(
            on: sqlite,
            table: "StillAliveSignal",
            installIdColumn: "installId",
            filter: "1 = 1",
            windows: windows
        )

        // Like `chapters-usage-analytics`, but people instead of taps.
        let chapterUsers = try await comparison(
            on: sqlite,
            table: "UsageMetric",
            installIdColumn: "customInstallId",
            filter: StatisticsController.chapterTapFilter,
            windows: windows
        )

        // Like `games-analytics`: players started a game, test devices left out.
        let testIdList = StatisticsController.testInstallIds.map { "'\($0)'" }.joined(separator: ",")
        let gamePlayersRows = try await sqlite.query("""
            SELECT COUNT(DISTINCT customInstallId) AS players
            FROM UsageMetric
            WHERE dateTime >= ?
              AND originatingScreen = '\(GameUsageEvent.gameScreen)'
              AND destinationScreen LIKE 'didStartGame(%'
              AND customInstallId NOT IN (\(testIdList))
            """, [.text(windows.todayStart)]).get()
        let gamePlayers = gamePlayersRows.first?.column("players")?.integer ?? 0

        // Like `version-distribution`: the share is out of the per-version counts.
        let versionRows = try await sqlite.query("""
            SELECT appVersion, COUNT(DISTINCT installId) AS users
            FROM StillAliveSignal
            WHERE dateTime >= ?
            GROUP BY appVersion
            ORDER BY users DESC
            """, [.text(windows.todayStart)]).get()
        let versionCounts = versionRows.map { row in
            (row.column("appVersion")?.string ?? "", row.column("users")?.integer ?? 0)
        }
        let versionTotal = versionCounts.reduce(0) { $0 + $1.1 }
        let topVersion = versionCounts.first.map { version, users in
            WidgetSummaryResponse.TopVersion(
                appVersion: version,
                uniqueUsers: users,
                percentage: versionTotal > 0 ? (Double(users) / Double(versionTotal) * 1000).rounded() / 10 : 0
            )
        }

        return WidgetSummaryResponse(
            day: windows.day,
            activeUsers: activeUsers,
            chapterUsers: chapterUsers,
            gamePlayers: gamePlayers,
            topVersion: topVersion,
            generatedAt: now.iso8601withFractionalSeconds
        )
    }

    /// All three counts in one pass over the last two days. `dateTime` is an ISO 8601 UTC
    /// string, so comparing it as text compares the instants.
    private static func comparison(
        on sqlite: SQLiteDatabase,
        table: String,
        installIdColumn: String,
        filter: String,
        windows: Windows
    ) async throws -> WidgetSummaryResponse.DayComparison {
        let rows = try await sqlite.query("""
            SELECT
                COUNT(DISTINCT CASE WHEN dateTime >= ? THEN \(installIdColumn) END) AS today,
                COUNT(DISTINCT CASE WHEN dateTime < ? THEN \(installIdColumn) END) AS yesterday,
                COUNT(DISTINCT CASE WHEN dateTime < ? THEN \(installIdColumn) END) AS yesterdayUntilNow
            FROM \(table)
            WHERE dateTime >= ?
              AND \(filter)
            """, [
                .text(windows.todayStart),
                .text(windows.todayStart),
                .text(windows.yesterdayUntilNow),
                .text(windows.yesterdayStart)
            ]).get()
        let row = rows.first
        return WidgetSummaryResponse.DayComparison(
            today: row?.column("today")?.integer ?? 0,
            yesterday: row?.column("yesterday")?.integer ?? 0,
            yesterdayUntilNow: row?.column("yesterdayUntilNow")?.integer ?? 0
        )
    }
}
