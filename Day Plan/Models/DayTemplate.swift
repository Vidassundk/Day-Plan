import Foundation
import SwiftData
import SwiftUI

/// A named day “blueprint” containing scheduled plan instances.
/// Users can assign a template to weekdays or open/edit it directly.
///
/// Architecture notes:
/// - This model carries only **facts** (name, scheduled plans).
/// - Policy like “what is a day?” lives in the engine (00:00–24:00).
/// - The effective start time is computed from content, not stored state.
@Model
final class DayTemplate {
    @Attribute(.unique) var id: UUID

    /// Friendly name shown in lists (e.g., "Workday", "Weekend").
    var name: String

    /// All concrete occurrences for this template.
    /// Delete rule `.cascade` removes the time slots when the template is deleted.
    /// Inverse relationship is `ScheduledPlan.dayTemplate`.
    @Relationship(deleteRule: .cascade, inverse: \ScheduledPlan.dayTemplate)
    var scheduledPlans: [ScheduledPlan] = []

    // MARK: - Init

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Derived properties (no persisted policy)

extension DayTemplate {
    /// Effective start of the template's day for UI/editor anchoring.
    ///
    /// Design:
    /// - If there are scheduled plans, we use the **earliest** plan start.
    ///   This makes empty mornings reflect real content.
    /// - If empty, we fall back to **today's 00:00** (strict calendar day).
    ///
    /// Why not store this?
    /// - Storing causes drift and “which field wins?” ambiguity.
    /// - Computing keeps the model factual and pushes policy to the engine/VM.
    var dayStart: Date {
        if let earliest = scheduledPlans.min(by: { $0.startTime < $1.startTime }
        )?.startTime {
            return earliest
        }
        return Calendar.current.startOfDay(for: .now)
    }

    /// Convenience accessor: plans sorted by `startTime` (useful for lists).
    var plansSorted: [ScheduledPlan] {
        scheduledPlans.sorted { $0.startTime < $1.startTime }
    }
}
