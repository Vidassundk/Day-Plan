import Foundation

/// A lightweight, unsaved block used while creating a template.
/// Holds a stable `planID` plus text/emoji snapshots for resilient display.
struct PlanEntryDraft: Identifiable, Equatable {
    let id = UUID()

    /// Target `Plan` identity. Used to resolve live data (or mark as deleted).
    let planID: UUID

    /// Snapshots ensure the row still shows something if the plan gets deleted.
    let titleSnapshot: String
    let emojiSnapshot: String

    /// Start time-of-day on the anchor date (the anchor is supplied by the VM).
    var start: Date

    /// Length in minutes (clamped by VM to stay within a single day).
    var lengthMinutes: Int

    init(existingPlan: Plan, start: Date, lengthMinutes: Int) {
        self.planID = existingPlan.id
        self.titleSnapshot = existingPlan.title
        self.emojiSnapshot = existingPlan.emoji
        self.start = start
        self.lengthMinutes = lengthMinutes
    }
}
