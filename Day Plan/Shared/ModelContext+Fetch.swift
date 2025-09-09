import Foundation
import SwiftData

/// Narrow, test-friendly fetch helpers.
/// Keep complex queries out of Views and VMs where possible.
extension ModelContext {
    /// Fetch a `Plan` by `id`. Returns `nil` if not found.
    func plan(with id: UUID) -> Plan? {
        let fd = FetchDescriptor<Plan>(predicate: #Predicate { $0.id == id })
        return try? fetch(fd).first
    }

    /// Fetch a `DayTemplate` by `id`. Returns `nil` if not found.
    func dayTemplate(with id: UUID) -> DayTemplate? {
        let fd = FetchDescriptor<DayTemplate>(
            predicate: #Predicate { $0.id == id })
        return try? fetch(fd).first
    }

    /// Fetch all `ScheduledPlan`s belonging to a template, sorted by start time.
    func scheduledPlans(for templateID: UUID) -> [ScheduledPlan] {
        let fd = FetchDescriptor<ScheduledPlan>(
            predicate: #Predicate { $0.dayTemplate?.id == templateID }
        )
        return (try? fetch(fd).sorted { $0.startTime < $1.startTime }) ?? []
    }
}
