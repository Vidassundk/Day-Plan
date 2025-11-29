import Foundation

/// ViewModel for `TimelineSpineRow`.
/// Encapsulates time/status/progress calculations for testability.
@MainActor
final class TimelineSpineRowViewModel: ObservableObject {
    enum Status { case past, current, upcoming }

    let sp: ScheduledPlan

    init(sp: ScheduledPlan) { self.sp = sp }

    /// Current status of the scheduled block relative to `now`.
    /// Projects the plan's time-of-day onto the current day to handle recurring templates.
    func status(now: Date) -> Status {
        let start = projectToToday(sp.startTime, now: now)
        let end = projectToToday(sp.endTime, now: now)
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    /// Fractional progress in the current block (0…1). Zero for non-current.
    func liveProgress(now: Date) -> Double {
        guard status(now: now) == .current else { return 0 }
        let start = projectToToday(sp.startTime, now: now)
        let end = projectToToday(sp.endTime, now: now)
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    /// Formatted "HH:mm – HH:mm · Xh Ym" for display.
    func timeRangeString() -> String {
        let start = sp.startTime
        let end = sp.endTime
        let mins = Int(sp.duration / 60)
        return
            "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(mins))"
    }
    
    /// Projects a scheduled plan's time onto today's date, preserving the time-of-day.
    /// This ensures that template plans (which may have been created on a different day)
    /// are evaluated relative to the current day for status calculations.
    private func projectToToday(_ date: Date, now: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
        let todayStart = calendar.startOfDay(for: now)
        return calendar.date(byAdding: timeComponents, to: todayStart) ?? date
    }
}
