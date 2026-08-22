import XCTest
@testable import OpenUsage

/// Boundary coverage for `docs/2- 时间显示算法.md`'s tier ladder and rounding edge cases.
final class ResetTimeFormatterTests: XCTestCase {

    func testSubMinuteFloorsToOneMinute() {
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 20.0 / 3600), "Resets in 1 min")
    }

    func testMinutesRound() {
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 45.0 / 60), "Resets in 45 min")
    }

    func testJustUnderOneHourStaysMinutes() {
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 59.9 / 60), "Resets in 60 min")
    }

    func testHoursRound() {
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 2.4), "Resets in 2 hr")
    }

    func testHoursRoundingUpTo24PromotesToTomorrow() {
        // 23.6h rounds to 24 at whole-hour precision — must fall into "tomorrow", never print "24 hr".
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 23.6), "Resets tomorrow")
    }

    func testJustUnder24HoursStaysHours() {
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 23.4), "Resets in 23 hr")
    }

    func testTwentyFourToFortyEightIsTomorrow() {
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 24), "Resets tomorrow")
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 47.9), "Resets tomorrow")
    }

    func testFortyEightHoursPromotesToDays() {
        // Boundary uses `<`, not `<=` — exactly 48h falls into the days tier.
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 48), "Resets in 2 days")
    }

    func testDaysRoundAndFloorAtOne() {
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 49), "Resets in 2 days")
        XCTAssertEqual(ResetTimeFormatter.format(hoursUntilReset: 300), "Resets in 13 days")
    }
}
