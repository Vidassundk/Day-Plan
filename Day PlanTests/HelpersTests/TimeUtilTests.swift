import XCTest

@testable import Day_Plan

final class TimeUtilTests: XCTestCase {

    func testAnchoredTime_preservesHourMinuteOnAnchorDay() {
        // Educational note:
        // "Preserves hour:minute" must be asserted relative to the SAME calendar
        // (i.e., time zone context) that we use for anchoring. Using a fixed
        // calendar also makes the test deterministic across environments.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!  // deterministic context

        let time = FixedDates.jan2_1545
        let anchor = FixedDates.jan1

        let anchored = TimeUtil.anchoredTime(time, to: anchor, calendar: cal)

        // Expect the anchored date to have the same wall-clock components as `time`
        // in the chosen calendar, but live on the anchor's day.
        XCTAssertEqual(
            cal.component(.hour, from: anchored),
            cal.component(.hour, from: time))
        XCTAssertEqual(
            cal.component(.minute, from: anchored),
            cal.component(.minute, from: time))
        XCTAssertEqual(
            cal.startOfDay(for: anchored),
            cal.startOfDay(for: anchor))
    }

    func testFormatMinutes() {
        XCTAssertEqual(TimeUtil.formatMinutes(90), "1h 30m")
        XCTAssertEqual(TimeUtil.formatMinutes(60), "1h")
        XCTAssertEqual(TimeUtil.formatMinutes(45), "45m")
        XCTAssertEqual(TimeUtil.formatMinutes(0), "0m")
    }
}
