import Foundation
import SwiftData

/// Narrow, test-friendly fetch helpers for SwiftData.
/// Design:
/// - Keep queries out of Views and (most) ViewModels to reduce coupling.
/// - Prefer small, readable helpers over ad-hoc fetch code sprinkled around.
/// - Marked `@MainActor` because this app uses its `ModelContext` on the main thread.
extension ModelContext {
    // MARK: - Single-entity lookups

    /// Fetch a `Plan` by `id`. Returns `nil` if not found.
    @MainActor
    func plan(with id: UUID) -> Plan? {
        let fd = FetchDescriptor<Plan>(predicate: #Predicate { $0.id == id })
        return try? fetch(fd).first
    }

    /// Fetch a `DayTemplate` by `id`. Returns `nil` if not found.
    @MainActor
    func dayTemplate(with id: UUID) -> DayTemplate? {
        let fd = FetchDescriptor<DayTemplate>(
            predicate: #Predicate { $0.id == id })
        return try? fetch(fd).first
    }

    // MARK: - Collections (simple, common cases)

    /// All `Plan` rows (unordered). Useful for pickers and seeders.
    @MainActor
    func plans() -> [Plan] {
        (try? fetch(FetchDescriptor<Plan>())) ?? []
    }

    /// All `DayTemplate` rows (unordered). Useful for admin/seed screens.
    @MainActor
    func dayTemplates() -> [DayTemplate] {
        (try? fetch(FetchDescriptor<DayTemplate>())) ?? []
    }

    /// All `WeekdayAssignment` rows (unordered).
    @MainActor
    func assignments() -> [WeekdayAssignment] {
        (try? fetch(FetchDescriptor<WeekdayAssignment>())) ?? []
    }

    // MARK: - Filtered collections

    /// All `ScheduledPlan`s belonging to a template, sorted by start time (ascending).
    @MainActor
    func scheduledPlans(for templateID: UUID) -> [ScheduledPlan] {
        let fd = FetchDescriptor<ScheduledPlan>(
            predicate: #Predicate { $0.dayTemplate?.id == templateID }
        )
        return (try? fetch(fd).sorted { $0.startTime < $1.startTime }) ?? []
    }

    /// Find the assignment for a specific weekday, if any.
    @MainActor
    func assignment(for weekday: Weekday) -> WeekdayAssignment? {
        let fd = FetchDescriptor<WeekdayAssignment>(
            predicate: #Predicate { $0.weekdayRaw == weekday.rawValue }
        )
        return (try? fetch(fd))?.first
    }
}
