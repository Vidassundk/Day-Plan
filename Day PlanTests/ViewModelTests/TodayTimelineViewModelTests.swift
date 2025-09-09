import XCTest

@testable import Day_Plan

@MainActor
final class TodayTimelineViewModelTests: XCTestCase {

    func testDayBounds_is24Hours() {
        let t = DayTemplate(name: "X", startTime: FixedDates.jan1)
        let vm = TodayTimelineViewModel(templateID: UUID())  // ID irrelevant for helpers
        let b = vm.dayBounds(for: t)
        XCTAssertEqual(b.start, FixedDates.jan1)
        XCTAssertEqual(
            b.end.timeIntervalSince(b.start), 24 * 60 * 60, accuracy: 0.5)
    }

    func testAnchoredNow_isClampedIntoDay() {
        let vm = TodayTimelineViewModel(templateID: UUID())
        let start = FixedDates.jan1
        let end = start.addingTimeInterval(24 * 60 * 60)

        // Before day → clamp to start (but keep time-of-day if within range)
        let early = FixedDates.make(2024, 12, 31, 5, 0, 0)
        let a1 = vm.anchoredNow(early, dayStart: start, dayEnd: end)
        XCTAssertGreaterThanOrEqual(a1, start)

        // After day → clamp to end
        let late = FixedDates.make(2025, 1, 2, 3, 0, 0)
        let a2 = vm.anchoredNow(late, dayStart: start, dayEnd: end)
        XCTAssertLessThanOrEqual(a2, end)

        // Mid-day → stays same time-of-day on anchor date.
        // Educational note: assert using the SAME calendar that 'anchoredNow'
        // uses internally (Calendar.current) to avoid time-zone brittleness.
        let mid = FixedDates.make(2026, 5, 5, 14, 20, 0)
        let a3 = vm.anchoredNow(mid, dayStart: start, dayEnd: end)
        let cal = Calendar.current

        XCTAssertEqual(
            cal.component(.hour, from: a3),
            cal.component(.hour, from: mid))
        XCTAssertEqual(
            cal.component(.minute, from: a3),
            cal.component(.minute, from: mid))
        XCTAssertEqual(
            cal.startOfDay(for: a3),
            cal.startOfDay(for: start))
    }
}
