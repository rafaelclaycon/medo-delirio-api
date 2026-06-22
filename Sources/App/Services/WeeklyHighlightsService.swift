import Vapor
import Fluent
import APNS
import SQLiteNIO

struct WeeklyHighlightsSendResult: Content {
    let notificationType: String
    let topContentName: String
    let weekNumber: Int
    let sentCount: Int
    let deviceIds: [String]
    let errors: [String]
}

struct WeeklyHighlightsService {

    let app: Application

    private static let lastSentKey = "weekly_highlights_last_sent"

    private static var brtDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return f
    }()

    func sendWeeklyHighlights(force: Bool = false) async -> WeeklyHighlightsSendResult? {
        let db = app.db
        let today = Self.brtDateFormatter.string(from: Date())

        if !force {
            let lastSent = try? await ServerSettingRepository.get(key: Self.lastSentKey, db: db)
            if lastSent == today {
                app.logger.info("Weekly highlights: already sent today (\(today)), skipping")
                return nil
            }
            // Record before sending — prevents double-fire if the server restarts mid-window
            try? await ServerSettingRepository.set(key: Self.lastSentKey, value: today, db: db)
        }

        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        let isSoundsWeek = weekOfYear % 2 == 0

        app.logger.info("Weekly highlights: week \(weekOfYear) → sending \(isSoundsWeek ? "sounds" : "reactions")")

        do {
            let result: WeeklyHighlightsSendResult?
            if isSoundsWeek {
                result = try await sendTopSoundsNotification(weekNumber: weekOfYear)
            } else {
                result = try await sendTopReactionsNotification(weekNumber: weekOfYear)
            }
            if let result {
                await persistLog(result, db: db)
            }
            return result
        } catch {
            app.logger.error("Weekly highlights: error - \(error)")
            return nil
        }
    }

    /// Records a row for this send so `/weekly-highlights-stats` can report how
    /// many highlights went out each week. Best-effort: a logging failure must
    /// not fail the broadcast that already happened.
    private func persistLog(_ result: WeeklyHighlightsSendResult, db: Database) async {
        do {
            try await WeeklyHighlightLog(
                weekNumber: result.weekNumber,
                notificationType: result.notificationType,
                topContentName: result.topContentName,
                sentCount: result.sentCount,
                dateTime: Date().iso8601withFractionalSeconds
            ).save(on: db)
        } catch {
            app.logger.error("Weekly highlights: failed to persist send log - \(error)")
        }
    }

    private func sendTopSoundsNotification(weekNumber: Int) async throws -> WeeklyHighlightsSendResult? {
        guard let sqlite = app.db as? SQLiteDatabase else {
            app.logger.error("Weekly highlights: database is not SQLite")
            return nil
        }

        let query = """
            SELECT c.title AS contentName, sum(s.shareCount) AS totalShareCount
            FROM ShareCountStat s
            INNER JOIN MedoContent c ON c.id = s.contentId
            WHERE c.contentType = 0
              AND s.dateTime > datetime('now', '-7 days')
            GROUP BY s.contentId
            ORDER BY totalShareCount DESC
            LIMIT 3
        """

        let rows = try await sqlite.query(query).get()

        guard let topName = rows.first?.column("contentName")?.string else {
            app.logger.warning("Weekly highlights: no sound data for the past 7 days, skipping")
            return nil
        }

        let notification = TypedNotification(
            aps: .init(alert: .init(
                title: "Top da Semana 🏆",
                body: "\"\(topName)\" foi o mais compartilhado. Veja o top 3."
            )),
            type: "weekly_top_sounds"
        )

        let result = await broadcast(notification: notification)

        return WeeklyHighlightsSendResult(
            notificationType: "weekly_top_sounds",
            topContentName: topName,
            weekNumber: weekNumber,
            sentCount: result.sentCount,
            deviceIds: result.deviceIds,
            errors: result.errors
        )
    }

    private func sendTopReactionsNotification(weekNumber: Int) async throws -> WeeklyHighlightsSendResult? {
        guard let sqlite = app.db as? SQLiteDatabase else {
            app.logger.error("Weekly highlights: database is not SQLite")
            return nil
        }

        let query = """
            SELECT
                replace(replace(destinationScreen, 'didViewReaction(', ''), ')', '') AS reaction,
                count(*) AS reactionCount
            FROM UsageMetric
            WHERE destinationScreen LIKE 'didViewReaction%'
              AND destinationScreen != 'didViewReactionsTab'
              AND dateTime >= datetime('now', '-7 days')
            GROUP BY reaction
            ORDER BY reactionCount DESC
            LIMIT 3
        """

        let rows = try await sqlite.query(query).get()

        guard let topName = rows.first?.column("reaction")?.string else {
            app.logger.warning("Weekly highlights: no reaction data for the past 7 days, skipping")
            return nil
        }

        let notification = TypedNotification(
            aps: .init(alert: .init(
                title: "Reação da Semana 🎭",
                body: "\"\(topName)\" foi a reação mais usada. Veja o top 3."
            )),
            type: "weekly_top_reactions"
        )

        let result = await broadcast(notification: notification)

        return WeeklyHighlightsSendResult(
            notificationType: "weekly_top_reactions",
            topContentName: topName,
            weekNumber: weekNumber,
            sentCount: result.sentCount,
            deviceIds: result.deviceIds,
            errors: result.errors
        )
    }

    private func broadcast(notification: TypedNotification) async -> (sentCount: Int, deviceIds: [String], errors: [String]) {
        let db = app.db
        var sentCount = 0
        var sentDeviceIds: [String] = []
        var errors: [String] = []

        do {
            guard let channel = try await PushChannel.query(on: db)
                .filter(\PushChannel.$channelId, .equal, "weekly_highlights")
                .with(\.$devices)
                .first()
            else {
                app.logger.warning("Weekly highlights: 'weekly_highlights' channel not found")
                return (0, [], ["'weekly_highlights' channel not found"])
            }

            let devices = channel.devices
            guard !devices.isEmpty else {
                app.logger.info("Weekly highlights: no devices subscribed to 'weekly_highlights'")
                return (0, [], [])
            }

            for device in devices {
                guard let token = device.pushToken, !token.isEmpty else { continue }
                do {
                    try await app.apns.send(notification, to: token).get()
                    sentCount += 1
                    sentDeviceIds.append(device.installId)
                } catch {
                    let desc = String(describing: error).lowercased()
                    if desc.contains("baddevicetoken") || desc.contains("unregistered") {
                        try? await device.delete(on: db)
                        let msg = "Deleted invalid token for device \(device.installId)"
                        app.logger.info("Weekly highlights: \(msg)")
                        errors.append(msg)
                    } else {
                        let msg = "Failed to send to \(device.installId): \(error)"
                        app.logger.error("Weekly highlights: \(msg)")
                        errors.append(msg)
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            app.logger.info("Weekly highlights: sent \(sentCount)/\(devices.count) notifications")
        } catch {
            let msg = "Failed to query channel: \(error)"
            app.logger.error("Weekly highlights: \(msg)")
            errors.append(msg)
        }

        return (sentCount, sentDeviceIds, errors)
    }
}
