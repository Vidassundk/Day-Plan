import XCTest

@testable import Day_Plan

final class TimeUtilTests: XCTestCase {

    func testAnchoredTime_preservesHourMinuteOnAnchorDay() {
        let time = FixedDates.jan2_1545
        let anchor = FixedDates.jan1
        let anchored = TimeUtil.anchoredTime(time, to: anchor)

        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: anchored), 15)
        XCTAssertEqual(cal.component(.minute, from: anchored), 45)
    }

    func testFormatMinutes() {
        XCTAssertEqual(TimeUtil.formatMinutes(90), "1h 30m")
        XCTAssertEqual(TimeUtil.formatMinutes(60), "1h")
        XCTAssertEqual(TimeUtil.formatMinutes(45), "45m")
        XCTAssertEqual(TimeUtil.formatMinutes(0), "0m")
    }
}
