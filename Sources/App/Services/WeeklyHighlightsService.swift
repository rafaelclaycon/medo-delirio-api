import Vapor
import APNS
import SQLiteNIO

struct WeeklyHighlightsService {

    let app: Application

    private static let lastSentKey = "weekly_highlights_last_sent"

    private static var brtDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return f
    }()

    func sendWeeklyHighlights(force: Bool = false) async {
        let db = app.db
        let today = Self.brtDateFormatter.string(from: Date())

        if !force {
            let lastSent = try? await ServerSettingRepository.get(key: Self.lastSentKey, db: db)
            if lastSent == today {
                app.logger.info("Weekly highlights: already sent today (\(today)), skipping")
                return
            }
            // Record before sending — prevents double-fire if the server restarts mid-window
            try? await ServerSettingRepository.set(key: Self.lastSentKey, value: today, db: db)
        }

        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        let isSoundsWeek = weekOfYear % 2 == 0

        app.logger.info("Weekly highlights: week \(weekOfYear) → sending \(isSoundsWeek ? "sounds" : "reactions")")

        do {
            if isSoundsWeek {
                try await sendTopSoundsNotification()
            } else {
                try await sendTopReactionsNotification()
            }
        } catch {
            app.logger.error("Weekly highlights: error - \(error)")
        }
    }

    private func sendTopSoundsNotification() async throws {
        guard let sqlite = app.db as? SQLiteDatabase else {
            app.logger.error("Weekly highlights: database is not SQLite")
            return
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
            return
        }

        let notification = TypedNotification(
            aps: .init(alert: .init(
                title: "Top da semana 🏆",
                body: "'\(topName)' foi o mais compartilhado. Veja o top 3"
            )),
            type: "weekly_top_sounds"
        )

        await broadcast(notification: notification)
    }

    private func sendTopReactionsNotification() async throws {
        guard let sqlite = app.db as? SQLiteDatabase else {
            app.logger.error("Weekly highlights: database is not SQLite")
            return
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
            return
        }

        let notification = TypedNotification(
            aps: .init(alert: .init(
                title: "Reações da semana ⚡",
                body: "'\(topName)' foi a reação mais usada. Veja o top 3"
            )),
            type: "weekly_top_reactions"
        )

        await broadcast(notification: notification)
    }

    private func broadcast(notification: TypedNotification) async {
        let db = app.db

        do {
            guard let channel = try await PushChannel.query(on: db)
                .filter(\PushChannel.$channelId, .equal, "weekly_highlights")
                .with(\.$devices)
                .first()
            else {
                app.logger.warning("Weekly highlights: 'weekly_highlights' channel not found")
                return
            }

            let devices = channel.devices
            guard !devices.isEmpty else {
                app.logger.info("Weekly highlights: no devices subscribed to 'weekly_highlights'")
                return
            }

            var sentCount = 0
            for device in devices {
                guard let token = device.pushToken, !token.isEmpty else { continue }
                do {
                    try await app.apns.send(notification, to: token).get()
                    sentCount += 1
                } catch {
                    let desc = String(describing: error).lowercased()
                    if desc.contains("baddevicetoken") || desc.contains("unregistered") {
                        try? await device.delete(on: db)
                        app.logger.info("Weekly highlights: deleted invalid token for device \(device.installId)")
                    } else {
                        app.logger.error("Weekly highlights: failed to send push to \(device.installId): \(error)")
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            app.logger.info("Weekly highlights: sent \(sentCount)/\(devices.count) notifications")
        } catch {
            app.logger.error("Weekly highlights: failed to query channel - \(error)")
        }
    }
}
