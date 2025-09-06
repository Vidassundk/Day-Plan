import Foundation
import SwiftData

// MARK: - Plan Model
/// Represents a generic, reusable activity or task.
/// A Plan itself has no timing information; it's a blueprint for an activity
/// that can be scheduled in multiple `DayTemplate`s at different times and for
/// different durations.

@Model
final class Plan {
    @Attribute(.unique) var id: UUID
    var title: String
    var planDescription: String?
    var emoji: String

    // Add this relationship so that deleting a Plan deletes its scheduled usages
    @Relationship(deleteRule: .cascade, inverse: \ScheduledPlan.plan)
    var scheduledUsages: [ScheduledPlan] = []

    init(title: String, planDescription: String? = nil, emoji: String) {
        self.id = UUID()
        self.title = title
        self.planDescription = planDescription
        self.emoji = emoji
    }
}
