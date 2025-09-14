import Foundation
import SwiftData
import SwiftUI

/// MVVM for `TodayTimelineView`.
/// Owns *derived* timeline state and policy for "what counts as today".
/// - No UI code here (formatting/layout lives in the views).
/// - Time math rules delegate to the engine (`DayWindow`, `TimeUtil`).
@MainActor
final class TodayTimelineViewModel: ObservableObject {
    // MARK: Identity & data access
    private let templateID: UUID
    private weak var modelContext: ModelContext?

    /// Inject a clock to make time-dependent logic testable.
    /// Default uses the system clock; tests can override with a fixed value.
    var nowProvider: () -> Date = { Date() }

    init(templateID: UUID) {
        self.templateID = templateID
    }

    func attach(context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Data queries (optional helpers; the view also uses @Query)
    func template() -> DayTemplate? {
        modelContext?.dayTemplate(with: templateID)
    }

    func plansSorted() -> [ScheduledPlan] {
        modelContext?.scheduledPlans(for: templateID) ?? []
    }

    // MARK: - Day policy (00:00–24:00 single, strict calendar day)
    /// The window for **today** (in the user's current calendar/timezone).
    /// This is the single source of truth for the day's start/end everywhere in the timeline UI.
    func dayWindow(for date: Date? = nil) -> DayWindow {
        let anchor = date ?? nowProvider()
        return DayWindow.ofDay(containing: anchor)
    }

    /// Clamp `date` into `[dayStart, dayEnd]` *while keeping the chosen time-of-day*.
    /// This keeps TimelineView's `context.date` safely inside today's visible domain.
    func anchoredNow(_ date: Date, dayStart: Date, dayEnd: Date) -> Date {
        let anchored = TimeUtil.anchoredTime(date, to: dayStart)
        return min(max(anchored, dayStart), dayEnd)
    }

    // MARK: - Row coloring / status (view uses this for spine blending)
    enum Status { case past, current, upcoming }

    func status(of sp: ScheduledPlan, now: Date) -> Status {
        let start = sp.startTime
        let end = sp.endTime
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    /// The color a row contributes to the vertical spine (used by neighbors).
    /// Design intent:
    /// - past → primary (de-emphasized)
    /// - current → plan tint (accented)
    /// - upcoming → separator (quiet)
    func outputColor(for sp: ScheduledPlan, now: Date) -> Color {
        switch status(of: sp, now: now) {
        case .past:
            return .primary
        case .current:
            return sp.plan?.tintColor ?? .accentColor
        case .upcoming:
            return Color(uiColor: .separator)
        }
    }

    /// Project a scheduled plan’s start onto the visible day window.
    func projectedStart(for sp: ScheduledPlan, in window: DayWindow) -> Date {
        TimeUtil.anchoredTime(sp.startTime, to: window.start)
    }

    /// End-of-block projected into today's window using strict clamping.
    /// This avoids the "00:00 means already finished" bug.
    func projectedEnd(for sp: ScheduledPlan, in window: DayWindow) -> Date {
        let start = projectedStart(for: sp, in: window)
        // Clamp to avoid spilling across 24:00
        let minutes = DayScheduleEngine.clampDurationWithinDay(
            start: start, requestedMinutes: Int(sp.duration / 60), day: window
        )
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
