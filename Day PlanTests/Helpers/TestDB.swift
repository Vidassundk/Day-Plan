import SwiftData
import XCTest

@testable import Day_Plan

enum TestDB {
    /// Build an in-memory SwiftData stack for fast, isolated tests.
    static func makeInMemory() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([
            Plan.self, ScheduledPlan.self, DayTemplate.self,
            WeekdayAssignment.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        return (container, context)
    }

    /// Convenience: insert a Plan.
    @discardableResult
    static func insertPlan(
        _ ctx: ModelContext,
        title: String = "Work",
        emoji: String = "💼",
        colorHex: String = ""
    ) -> Plan {
        let p = Plan(
            title: title, planDescription: nil, emoji: emoji, colorHex: colorHex
        )
        ctx.insert(p)
        try? ctx.save()
        return p
    }

    /// Convenience: insert a DayTemplate.
    @discardableResult
    static func insertTemplate(
        _ ctx: ModelContext, name: String = "Template", start: Date
    ) -> DayTemplate {
        let t = DayTemplate(name: name, startTime: start)
        ctx.insert(t)
        try? ctx.save()
        return t
    }
}
