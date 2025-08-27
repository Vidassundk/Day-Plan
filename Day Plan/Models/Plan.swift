import Foundation
import SwiftData

// MARK: - Plan Model
/// Represents a generic, reusable activity or task.
/// A Plan itself has no timing information; it's a blueprint for an activity
/// that can be scheduled in multiple `DayTemplate`s at different times and for
/// different durations.
@Model
final class Plan {
    /// A unique identifier for the plan, generated automatically.
    @Attribute(.unique) var id: UUID

    /// The title of the plan, e.g., "Morning Run", "Team Meeting".
    var title: String

    /// An optional, more detailed description of the plan.
    var planDescription: String?

    /// An emoji or symbol to visually represent the plan.
    var emoji: String

    /// An inverse relationship to track all the places this plan is scheduled.
    /// This is not typically used directly for building the schedule but is
    /// useful for data integrity and potential features like "where is this plan used?".
    ///
    /// The delete rule is `.nullify`, meaning if this `Plan` is deleted, the `plan`
    /// property in any associated `ScheduledPlan` object will be set to nil. This
    /// preserves the time slot in the template, which can then be reassigned.
    @Relationship(deleteRule: .nullify, inverse: \ScheduledPlan.plan)
    var scheduledIn: [ScheduledPlan]?

    init(title: String, planDescription: String? = nil, emoji: String) {
        self.id = UUID()
        self.title = title
        self.planDescription = planDescription
        self.emoji = emoji
    }
}
