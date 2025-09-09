import SwiftData
import SwiftUI
import XCTest

@testable import Day_Plan

@MainActor
final class DayTemplateEditorViewModel_CreateTests: XCTestCase {

    func testSaveTemplate_withDrafts_createsScheduledPlansAndClamps() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let plan = TestDB.insertPlan(ctx, title: "Late Block", emoji: "🌙")

        let vm = DayTemplateEditorViewModel(
            mode: DayTemplateEditorView.Mode.create())
        vm.attach(context: ctx)

        // Use the VM's anchor day to avoid timezone/DST surprises
        let anchor = vm.anchorDay
        // Start at 23:00 on anchor day, request 180m → should clamp to 60m
        let startLate = Calendar.current.date(
            byAdding: .hour, value: 23, to: anchor)!
        vm.appendDraft(plan: plan, start: startLate, lengthMinutes: 180)

        let saved = vm.saveTemplateCreate()
        XCTAssertNotNil(saved)

        // Verify scheduled items
        let sps = ctx.scheduledPlans(for: saved!.id)
        XCTAssertEqual(sps.count, 1)
        let sp = sps[0]
        XCTAssertEqual(Int(sp.duration / 60), 60)  // clamped
    }

    func testSaveTemplate_defaultNameWhenEmpty() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let plan = TestDB.insertPlan(ctx)

        let vm = DayTemplateEditorViewModel(
            mode: DayTemplateEditorView.Mode.create())
        vm.attach(context: ctx)
        vm.name = "   "  // will be trimmed to empty
        vm.appendDraft(plan: plan, start: vm.anchorDay, lengthMinutes: 30)
        let saved = vm.saveTemplateCreate()
        XCTAssertEqual(saved?.name, "New Day")
    }

    func testSortedDrafts_ordersByAnchoredStart() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let p = TestDB.insertPlan(ctx)
        let vm = DayTemplateEditorViewModel(
            mode: DayTemplateEditorView.Mode.create())
        vm.attach(context: ctx)
        let a = vm.anchorDay
        vm.appendDraft(
            plan: p, start: a.addingTimeInterval(60 * 120), lengthMinutes: 30)  // 02:00
        vm.appendDraft(
            plan: p, start: a.addingTimeInterval(60 * 30), lengthMinutes: 30)  // 00:30
        let sorted = vm.sortedDrafts()
        XCTAssertLessThan(sorted[0].start, sorted[1].start)
    }
}
