import SwiftData
import SwiftUI
import XCTest

@testable import Day_Plan

@MainActor
final class DayTemplateEditorViewModel_EditTests: XCTestCase {

    func testUpdateScheduled_clampsLengthToDayEnd() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let p = TestDB.insertPlan(ctx, title: "Late", emoji: "🌙")
        let tpl = TestDB.insertTemplate(ctx, start: FixedDates.jan1)

        // 23:00 start, 30m duration
        let sp = ScheduledPlan(
            plan: p, startTime: FixedDates.jan1_2300, duration: 30 * 60)
        sp.dayTemplate = tpl
        ctx.insert(sp)
        try? ctx.save()

        let vm = DayTemplateEditorViewModel(
            mode: DayTemplateEditorView.Mode.edit(tpl))
        vm.attach(context: ctx)

        vm.updateScheduled(sp, newMinutes: 180)  // would cross midnight → clamp
        XCTAssertEqual(Int(sp.duration / 60), 60)
    }

    func testAddScheduled_insertsAndClamps() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let p = TestDB.insertPlan(ctx, title: "Gym", emoji: "🏋️")
        let tpl = TestDB.insertTemplate(
            ctx, name: "Day", start: FixedDates.jan1)

        let vm = DayTemplateEditorViewModel(
            mode: DayTemplateEditorView.Mode.edit(tpl))
        vm.attach(context: ctx)

        // 23:00 start, ask 120m → clamp to 60
        vm.addScheduled(
            to: tpl.id, plan: p, start: FixedDates.jan1_2300, lengthMinutes: 120
        )

        let sps = ctx.scheduledPlans(for: tpl.id)
        XCTAssertEqual(sps.count, 1)
        XCTAssertEqual(Int(sps[0].duration / 60), 60)
    }
}
