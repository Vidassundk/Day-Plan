import Foundation
import SwiftData
import SwiftUI

/// MVVM for `TodayTimelineView`.
/// Fetches the template + plans and supplies derived timeline state.
@MainActor
final class TodayTimelineViewModel: ObservableObject {
    private let templateID: UUID
    private weak var modelContext: ModelContext?

    init(templateID: UUID) {
        self.templateID = templateID
    }

    func attach(context: ModelContext) {
        self.modelContext = context
    }

    func template() -> DayTemplate? {
        modelContext?.dayTemplate(with: templateID)
    }

    func plansSorted() -> [ScheduledPlan] {
        modelContext?.scheduledPlans(for: templateID) ?? []
    }

    func dayBounds(for template: DayTemplate) -> (start: Date, end: Date) {
        let start = template.startTime
        return (start, start.addingTimeInterval(24 * 60 * 60))
    }

    /// Clamp `date` to be within `[dayStart, dayEnd]` but keep the time-of-day.
    func anchoredNow(_ date: Date, dayStart: Date, dayEnd: Date) -> Date {
        let anchored = TimeUtil.anchoredTime(date, to: dayStart)
        return min(max(anchored, dayStart), dayEnd)
    }

    enum Status { case past, current, upcoming }

    func status(of sp: ScheduledPlan, now: Date) -> Status {
        let start = sp.startTime
        let end = sp.endTime
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    /// The color a row contributes to the vertical spine (used by neighbors).
    func outputColor(for sp: ScheduledPlan, now: Date) -> Color {
        switch status(of: sp, now: now) {
        case .past: return .primary
        case .current: return sp.plan?.tintColor ?? .accentColor
        case .upcoming: return Color(uiColor: .separator)
        }
    }
}
