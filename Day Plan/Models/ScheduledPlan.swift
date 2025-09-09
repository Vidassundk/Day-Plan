import Foundation
import SwiftData

/// Connects a `Plan` to a `DayTemplate` with time context
/// (`startTime` + `duration`). Deleting the template cascades; deleting the
/// plan nullifies the pointer so history/editing can survive.
@Model
final class ScheduledPlan {
    @Attribute(.unique) var id: UUID

    /// Scheduled start time (usually only H:M is meaningful).
    var startTime: Date

    /// Duration in seconds (TimeInterval is Double).
    var duration: TimeInterval

    /// The referenced reusable plan (optional for nullify-on-delete).
    var plan: Plan?

    /// Backlink to the owning template.
    var dayTemplate: DayTemplate?

    init(plan: Plan, startTime: Date, duration: TimeInterval) {
        self.id = UUID()
        self.plan = plan
        self.startTime = startTime
        self.duration = duration
    }

    /// Derived end timestamp = start + duration.
    var endTime: Date { startTime.addingTimeInterval(duration) }
}
