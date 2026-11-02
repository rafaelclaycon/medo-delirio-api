@testable import App
import Testing
import VaporTesting
import Foundation

struct WeeklyHighlightsScheduleTests {

    private static let brt = TimeZone(identifier: "America/Sao_Paulo")!

    /// 2026-10-23 is a Friday.
    private func brtDate(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.brt
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
    }

    private func delay(from date: Date) -> Int64 {
        WeeklyHighlightsLifecycle.secondsUntilNextFriday18BRT(from: date)
    }

    @Test func `Monday waits until Friday`() {
        #expect(delay(from: brtDate(19, 18)) == 4 * 24 * 3600)
    }

    @Test func `Friday morning waits until that evening`() {
        #expect(delay(from: brtDate(23, 9, 30)) == 8 * 3600 + 30 * 60)
    }

    @Test func `Just after sending waits a full week`() {
        #expect(delay(from: brtDate(23, 18, 0, 1)) == 7 * 24 * 3600 - 1)
    }

    @Test func `Friday night waits until next Friday`() {
        #expect(delay(from: brtDate(23, 21)) == 7 * 24 * 3600 - 3 * 3600)
    }

    @Test func `Saturday waits six days`() {
        #expect(delay(from: brtDate(24, 18)) == 6 * 24 * 3600)
    }

    @Test func `Waking just before 18 waits at least a minute`() {
        #expect(delay(from: brtDate(23, 17, 59, 59)) == 60)
    }

    @Test func `Uses Brasília time regardless of server time zone`() {
        // 20:30 UTC on a Friday is 17:30 in Brasília: still before the send.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 20, minute: 30))!
        #expect(delay(from: date) == 30 * 60)
    }
}
