import XCTest

@testable import Day_Plan

@MainActor
final class TimelineSpineRowViewModelTests: XCTestCase {

    func makeSP(start: Date, minutes: Int) -> ScheduledPlan {
        let plan = Plan(title: "Test", emoji: "🧪")
        return ScheduledPlan(
            plan: plan, startTime: start, duration: TimeInterval(minutes * 60))
    }

    func testStatus_beforeStart_isUpcoming() {
        let sp = makeSP(start: FixedDates.jan1_0900, minutes: 120)
        let vm = TimelineSpineRowViewModel(sp: sp)
        XCTAssertEqual(vm.status(now: FixedDates.jan1), .upcoming)
    }

    func testStatus_during_isCurrent() {
        let sp = makeSP(start: FixedDates.jan1_0900, minutes: 120)
        let vm = TimelineSpineRowViewModel(sp: sp)
        XCTAssertEqual(vm.status(now: FixedDates.jan1_1000), .current)
    }

    func testStatus_after_isPast() {
        let sp = makeSP(start: FixedDates.jan1_0900, minutes: 120)
        let vm = TimelineSpineRowViewModel(sp: sp)
        XCTAssertEqual(vm.status(now: FixedDates.jan1_1100), .past)
    }

    func testLiveProgress_onlyInCurrentWindow() {
        let sp = makeSP(start: FixedDates.jan1_0900, minutes: 120)
        let vm = TimelineSpineRowViewModel(sp: sp)

        XCTAssertEqual(vm.liveProgress(now: FixedDates.jan1), 0)  // not current
        XCTAssertEqual(vm.liveProgress(now: FixedDates.jan1_1000), 0.5)  // halfway
        XCTAssertEqual(vm.liveProgress(now: FixedDates.jan1_1100), 0)  // not current (past)
    }

    func testTimeRangeString_hasTimesAndLength() {
        let sp = makeSP(start: FixedDates.jan1_0900, minutes: 90)
        let vm = TimelineSpineRowViewModel(sp: sp)
        let text = vm.timeRangeString()
        XCTAssertTrue(text.contains("· 1h 30m"))
    }
}
