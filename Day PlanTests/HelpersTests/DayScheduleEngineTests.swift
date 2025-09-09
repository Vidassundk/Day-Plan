import XCTest

@testable import Day_Plan

final class DayScheduleEngineTests: XCTestCase {

    func testClamp_withStart2300_request180_clampsTo60() {
        let day = DayWindow(start: FixedDates.jan1)
        let start = FixedDates.jan1_2300
        let clamped = DayScheduleEngine.clampDurationWithinDay(
            start: start, requestedMinutes: 180, day: day)
        XCTAssertEqual(clamped, 60)
    }

    func testClamp_withinBounds_keepsRequested() {
        let day = DayWindow(start: FixedDates.jan1)
        let start = FixedDates.jan1_0900
        let clamped = DayScheduleEngine.clampDurationWithinDay(
            start: start, requestedMinutes: 30, day: day)
        XCTAssertEqual(clamped, 30)
    }

    func testClamp_negativeRequest_becomesZero() {
        let day = DayWindow(start: FixedDates.jan1)
        let start = FixedDates.jan1_0900
        let clamped = DayScheduleEngine.clampDurationWithinDay(
            start: start, requestedMinutes: -5, day: day)
        XCTAssertEqual(clamped, 0)
    }
}
