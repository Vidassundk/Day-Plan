import Foundation
import SwiftData

/// A placed block of time inside a `DayTemplate` that references a reusable `Plan`.
/// Deleting the template cascades; deleting the plan nullifies the pointer so the
/// time slot can remain visible (it will show "Untitled" in UI).
@Model
final class ScheduledPlan {
    @Attribute(.unique) var id: UUID

    /// Scheduled start time (calendar day anchoring is handled by the engine/VM).
    var startTime: Date

    /// Duration in seconds.
    var duration: TimeInterval

    /// Reusable plan this slot points to (nullable by design).
    /// We don’t declare an inverse here to avoid circular resolution errors.
    var plan: Plan?

    /// Owning template (inverse is declared on `DayTemplate.scheduledPlans`).
    var dayTemplate: DayTemplate?

    init(plan: Plan, startTime: Date, duration: TimeInterval) {
        self.id = UUID()
        self.plan = plan
        self.startTime = startTime
        self.duration = duration
    }

    /// Derived end timestamp.
    var endTime: Date { startTime.addingTimeInterval(duration) }
}
