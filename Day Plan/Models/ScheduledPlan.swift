import Foundation
import SwiftData

// MARK: - ScheduledPlan Model (Intermediate Model)
/// This is the "join" model that connects a `DayTemplate` with a `Plan`.
/// It holds the context-specific information: the start time and duration
/// of a particular `Plan` within a particular `DayTemplate`.
@Model
final class ScheduledPlan {
    /// A unique identifier for this specific scheduled instance.
    @Attribute(.unique) var id: UUID

    /// The time the plan is scheduled to start.
    /// Using `Date` allows for flexibility, though you might only use the time component.
    var startTime: Date

    /// The duration of the scheduled plan in seconds.
    /// Using `TimeInterval` (which is a Double) is standard for time durations.
    var duration: TimeInterval

    // The specific `Plan` being scheduled. If the original Plan is deleted,
    // this becomes nil due to the `.nullify` rule on the `Plan` model.
    var plan: Plan?

    // The `DayTemplate` this scheduled plan belongs to. This creates the
    // inverse side of the one-to-many relationship from `DayTemplate`.
    var dayTemplate: DayTemplate?

    init(plan: Plan, startTime: Date, duration: TimeInterval) {
        self.id = UUID()
        self.plan = plan
        self.startTime = startTime
        self.duration = duration
    }
}
