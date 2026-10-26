import Vapor
import Foundation

final class WeeklyHighlightsLifecycle: LifecycleHandler, @unchecked Sendable {

    private var task: Task<Void, Never>?

    func didBoot(_ app: Application) throws {
        let service = WeeklyHighlightsService(app: app)

        // Works out the next Friday 18:00 BRT before every wait instead of adding a fixed
        // week, so a slow send or a restart never shifts the schedule.
        task = Task {
            while !Task.isCancelled {
                let delay = Self.secondsUntilNextFriday18BRT(from: .now)
                let hours = delay / 3600
                let minutes = (delay % 3600) / 60
                app.logger.info("Weekly highlights scheduled every Friday at 18:00 BRT (next run in \(hours)h \(minutes)m)")

                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
                _ = await service.sendWeeklyHighlights()
            }
            app.logger.info("Weekly highlights: stopped")
        }
    }

    func shutdown(_ app: Application) {
        task?.cancel()
    }

    static func secondsUntilNextFriday18BRT(from now: Date) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!

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
        // At least a minute, so a wake-up that lands a hair before 18:00 can't loop.
        return Int64(max(60, targetDate.timeIntervalSince(now)))
    }
}
