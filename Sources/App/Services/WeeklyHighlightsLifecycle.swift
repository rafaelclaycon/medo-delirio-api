import Vapor
import NIOCore
import Foundation

struct WeeklyHighlightsLifecycle: LifecycleHandler {

    func didBoot(_ app: Application) throws {
        let initialDelay = secondsUntilNextFriday18BRT()
        let weeklyInterval: Int64 = 7 * 24 * 60 * 60

        app.eventLoopGroup.next().scheduleRepeatedTask(
            initialDelay: .seconds(initialDelay),
            delay: .seconds(weeklyInterval)
        ) { _ in
            Task {
                let service = WeeklyHighlightsService(app: app)
                await service.sendWeeklyHighlights()
            }
        }

        let hours = initialDelay / 3600
        let minutes = (initialDelay % 3600) / 60
        app.logger.info("Weekly highlights scheduled every Friday at 18:00 BRT (first run in \(hours)h \(minutes)m)")
    }

    private func secondsUntilNextFriday18BRT() -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!

        let now = Date()
        // weekday: 1 = Sunday, 6 = Friday
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        var daysToAdd = (6 - weekday + 7) % 7
        if daysToAdd == 0 && hour >= 18 {
            daysToAdd = 7
        }

        let targetDay = calendar.date(byAdding: .day, value: daysToAdd, to: now)!
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        components.hour = 18
        components.minute = 0
        components.second = 0
        components.nanosecond = 0

        let targetDate = calendar.date(from: components)!
        return Int64(max(60, targetDate.timeIntervalSince(now)))
    }
}
