import Foundation
import SwiftData

// MARK: - DayTemplate Model
/// Represents a template for a day, containing a collection of scheduled activities.
/// Each DayTemplate has a unique name and holds a list of `ScheduledPlan` objects,
/// which define the specific timing of each activity within this template.
@Model
final class DayTemplate {
    @Attribute(.unique) var id: UUID

    @Relationship(deleteRule: .nullify, inverse: \WeekdayAssignment.template)
    var weekdayAssignments: [WeekdayAssignment] = []

    var name: String

    var startTime: Date = Calendar.current.startOfDay(for: .now)

    @Relationship(deleteRule: .cascade, inverse: \ScheduledPlan.dayTemplate)
    var scheduledPlans: [ScheduledPlan] = []

    init(name: String, startTime: Date) {
        self.id = UUID()
        self.name = name
        self.startTime = startTime
    }

    // ✅ Makes existing call-sites like DayTemplate(name:) still compile
    convenience init(name: String) {
        self.init(name: name, startTime: Calendar.current.startOfDay(for: .now))
    }
}

extension DayTemplate {
    /// The effective day start = the earliest plan's start if any, else the internal anchor.
    var dayStart: Date {
        if let earliest = scheduledPlans.min(by: { $0.startTime < $1.startTime }
        )?.startTime {
            return earliest
        }
        return Calendar.current.startOfDay(for: .now)
    }
}
