@testable import App
import XCTVapor

final class WeeklyHighlightsScheduleTests: XCTestCase {

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

    func testMondayWaitsUntilFriday() {
        XCTAssertEqual(delay(from: brtDate(19, 18)), 4 * 24 * 3600)
    }

    func testFridayMorningWaitsUntilThatEvening() {
        XCTAssertEqual(delay(from: brtDate(23, 9, 30)), 8 * 3600 + 30 * 60)
    }

    func testJustAfterSendingWaitsAFullWeek() {
        XCTAssertEqual(delay(from: brtDate(23, 18, 0, 1)), 7 * 24 * 3600 - 1)
    }

    func testFridayNightWaitsUntilNextFriday() {
        XCTAssertEqual(delay(from: brtDate(23, 21)), 7 * 24 * 3600 - 3 * 3600)
    }

    func testSaturdayWaitsSixDays() {
        XCTAssertEqual(delay(from: brtDate(24, 18)), 6 * 24 * 3600)
    }

    func testWakingJustBefore18WaitsAtLeastAMinute() {
        XCTAssertEqual(delay(from: brtDate(23, 17, 59, 59)), 60)
    }

    func testUsesBrasiliaTimeRegardlessOfServerTimeZone() {
        // 20:30 UTC on a Friday is 17:30 in Brasília: still before the send.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 20, minute: 30))!
        XCTAssertEqual(delay(from: date), 30 * 60)
    }
}
