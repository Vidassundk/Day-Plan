import Foundation
import SwiftData
import SwiftUI

/// Domain model describing a reusable activity (title/emoji/color).
/// - Stored independently and scheduled via `ScheduledPlan`.
@Model
final class Plan {
    @Attribute(.unique) var id: UUID

    /// Display title for UI and search.
    var title: String

    /// Optional longer description (notes, details).
    var planDescription: String?

    /// Primary emoji to represent the plan in the UI.
    var emoji: String

    /// Hex color string (`#RRGGBB`). Empty = use `.accentColor`.
    var colorHex: String

    /// Reverse link to all schedule usages. Cascade ensures cleanup.
    @Relationship(deleteRule: .cascade, inverse: \ScheduledPlan.plan)
    var scheduledUsages: [ScheduledPlan] = []

    init(
        title: String,
        planDescription: String? = nil,
        emoji: String,
        colorHex: String = ""  // empty means "use accent color"
    ) {
        self.id = UUID()
        self.title = title
        self.planDescription = planDescription
        self.emoji = emoji
        self.colorHex = colorHex
    }

    /// A non-optional color the UI can always render.
    /// Falls back to `.accentColor` when `colorHex` is empty or invalid.
    var tintColor: Color {
        if colorHex.isEmpty { return .accentColor }
        return Color(hex: colorHex) ?? .accentColor
    }
}
