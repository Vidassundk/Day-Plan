import SwiftData
import SwiftUI
import XCTest

@testable import Day_Plan

@MainActor
final class DayTemplateEditorViewModel_EditTests: XCTestCase {

    /// Dynamic day window starts at 23:00 (first plan’s start).
    /// Asking for +180 minutes (to 02:00 next day) is still within 24h → NO clamp.
    func testUpdateScheduled_allowsWithinDynamicWindow() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let p = TestDB.insertPlan(ctx, title: "Late", emoji: "🌙")
        let T0 = FixedDates.jan1_2300  // 23:00 Jan 1
        let tpl = TestDB.insertTemplate(ctx, start: T0)  // anchor == 23:00

        // Seed one scheduled plan at the anchor.
        let sp = ScheduledPlan(plan: p, startTime: T0, duration: 30 * 60)
        sp.dayTemplate = tpl
        ctx.insert(sp)
        try? ctx.save()

        let vm = DayTemplateEditorViewModel(mode: .edit(tpl))
        vm.attach(context: ctx)

        // Ask for 180m total length starting at 23:00 → 02:00 next day.
        // That’s still within [23:00 Jan 1, 23:00 Jan 2) → no clamp expected.
        vm.updateScheduled(sp, newMinutes: 180)
        XCTAssertEqual(Int(sp.duration / 60), 180)
    }

    /// Start at 23:59 on the anchor day (i.e., *inside* the dynamic window, near its end).
    /// Only 23h01m remain until the window end (23:00 next day) → clamp to 1381 minutes.
    /// Start near the end of the *actual* dynamic window (vm.anchorDay + 24h),
    /// request way too much time, and expect a clamp to the exact remaining minutes.
    func testAddScheduled_clampsWhenRequestExceedsRemaining() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let p = TestDB.insertPlan(ctx, title: "Work", emoji: "💼")
        // Seed template; its stored anchor will be read via vm.anchorDay.
        let tpl = TestDB.insertTemplate(ctx, start: FixedDates.jan1_2300)

        let vm = DayTemplateEditorViewModel(mode: .edit(tpl))
        vm.attach(context: ctx)

        // Use the *real* anchor the editor uses for its 24h window.
        let anchor = vm.anchorDay
        // Choose a start 61 minutes before the window end.
        // (Using 61 instead of 1 gives us an hour+minute case.)
        let remaining = 61
        let startNearEnd = anchor.addingTimeInterval(
            TimeInterval((24 * 60 - remaining) * 60))
        let anchoredStart = TimeUtil.anchoredTime(startNearEnd, to: anchor)

        // Ask for something huge so it must clamp to the remaining window.
        vm.addScheduled(
            to: tpl.id, plan: p, start: startNearEnd, lengthMinutes: 5000)

        // Find the plan we just inserted at the anchored start.
        let cal = Calendar.current
        let sps = ctx.scheduledPlans(for: tpl.id)
        let target = sps.first {
            cal.component(.hour, from: $0.startTime)
                == cal.component(.hour, from: anchoredStart)
                && cal.component(.minute, from: $0.startTime)
                    == cal.component(.minute, from: anchoredStart)
        }
        XCTAssertNotNil(
            target, "Expected a ScheduledPlan at the anchored start time.")

        // Expect clamp to the exact remaining minutes.
        XCTAssertEqual(Int(target!.duration / 60), remaining)
    }

}
