import Foundation
import SwiftData

/// A named day “blueprint” containing scheduled plan instances.
/// Users can assign a template to weekdays or open/edit it directly.
@Model
final class DayTemplate {
    @Attribute(.unique) var id: UUID

    /// Friendly name shown in lists (e.g., "Workday", "Weekend").
    var name: String

    /// Anchor start for the day (used when there are no scheduled plans).
    var startTime: Date = Calendar.current.startOfDay(for: .now)

    /// All concrete occurrences for this template.
    @Relationship(deleteRule: .cascade, inverse: \ScheduledPlan.dayTemplate)
    var scheduledPlans: [ScheduledPlan] = []

    /// Weekday assignments that reference this template (nullify on delete).
    @Relationship(deleteRule: .nullify, inverse: \WeekdayAssignment.template)
    var weekdayAssignments: [WeekdayAssignment] = []

    init(name: String, startTime: Date) {
        self.id = UUID()
        self.name = name
        self.startTime = startTime
    }

    /// Convenience initializer using "today at 00:00" as anchor start.
    convenience init(name: String) {
        self.init(name: name, startTime: Calendar.current.startOfDay(for: .now))
    }
}

extension DayTemplate {
    /// Effective start of the day:
    /// - If there are scheduled plans, use the earliest plan's start.
    /// - Otherwise, fall back to the template's `startTime` anchor.
    var dayStart: Date {
        if let earliest = scheduledPlans.min(by: { $0.startTime < $1.startTime }
        )?.startTime {
            return earliest
        }
        return startTime
    }
}
