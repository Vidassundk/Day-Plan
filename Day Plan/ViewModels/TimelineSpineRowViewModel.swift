import Foundation

/// ViewModel for `TimelineSpineRow`.
/// Encapsulates time/status/progress calculations for testability.
@MainActor
final class TimelineSpineRowViewModel: ObservableObject {
    enum Status { case past, current, upcoming }

    let sp: ScheduledPlan

    init(sp: ScheduledPlan) { self.sp = sp }

    /// Current status of the scheduled block relative to `now`.
    func status(now: Date) -> Status {
        let start = sp.startTime
        let end = sp.endTime
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    /// Fractional progress in the current block (0…1). Zero for non-current.
    func liveProgress(now: Date) -> Double {
        guard status(now: now) == .current else { return 0 }
        let total = sp.endTime.timeIntervalSince(sp.startTime)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(sp.startTime) / total))
    }

    /// Formatted "HH:mm – HH:mm · Xh Ym" for display.
    func timeRangeString() -> String {
        let start = sp.startTime
        let end = sp.endTime
        let mins = Int(sp.duration / 60)
        return
            "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(mins))"
    }
}
