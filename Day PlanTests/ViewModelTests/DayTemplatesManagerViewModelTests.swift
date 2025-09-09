import SwiftData
import XCTest

@testable import Day_Plan

@MainActor
final class DayTemplatesManagerViewModelTests: XCTestCase {
    func testDeleteTemplates_removesAndSaves() throws {
        let (_, ctx) = try TestDB.makeInMemory()
        let t1 = TestDB.insertTemplate(ctx, name: "A", start: FixedDates.jan1)
        let t2 = TestDB.insertTemplate(ctx, name: "B", start: FixedDates.jan2)

        let vm = DayTemplatesManagerViewModel()
        var list = [t1, t2]
        vm.deleteTemplates(from: list, at: IndexSet(integer: 1), in: ctx)

        // Re-fetch to confirm deletion persisted
        let fd = FetchDescriptor<DayTemplate>()
        let all = try ctx.fetch(fd)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "A")
    }
}
