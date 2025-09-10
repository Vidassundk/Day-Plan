import Foundation

/// Time helpers used across timeline, editors, and validation flows.
public enum TimeUtil {
    /// Apply hour:minute:second of `time` onto the **date** of `anchor`.
    /// Keeps the chosen clock time while shifting it into a specific day.
    public static func anchoredTime(
        _ time: Date, to anchor: Date, calendar: Calendar = .current
    ) -> Date {
        let cal = calendar
        let h = cal.component(.hour, from: time)
        let m = cal.component(.minute, from: time)
        let s = cal.component(.second, from: time)
        return cal.date(
            bySettingHour: h, minute: m, second: s,
            of: cal.startOfDay(for: anchor)) ?? anchor
    }

    /// Convert minute counts to a compact, readable string (e.g., "1h 30m", "45m").
    public static func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

/// Represents a strict 24-hour window starting at `start` (00:00 of a calendar day).
/// Keep this as the single definition of “what is a day” to avoid drift.
public struct DayWindow {
    public let start: Date
    public var end: Date { start.addingTimeInterval(24 * 60 * 60) }

    public init(start: Date) { self.start = start }

    /// Factory: build a window for the **calendar day** that contains `anchor`.
    /// NOTE: avoids “user-defined Mondays”; UI and engine stay in sync.
    public static func ofDay(
        containing anchor: Date, calendar: Calendar = .current
    ) -> DayWindow {
        DayWindow(start: calendar.startOfDay(for: anchor))
    }
}

/// Pure operations that keep schedules within a single-day boundary.
/// These are easy to unit test and safe to call from Views/VMs.
public enum DayScheduleEngine {
    /// Truncate a requested duration (minutes) so that `start + duration` ≤ `day.end`.
    /// Overlaps with other **plans** can still be allowed by policy, but **not with the day boundary**.
    public static func clampDurationWithinDay(
        start: Date,
        requestedMinutes: Int,
        day: DayWindow
    ) -> Int {
        let maxSec = max(0, day.end.timeIntervalSince(start))
        let reqSec = TimeInterval(max(0, requestedMinutes) * 60)
        return Int(min(reqSec, maxSec) / 60)
    }
}

extension Date {
    /// Add minutes to a `Date` using `TimeInterval`. Convenient for editor math.
    public func adding(minutes: Int) -> Date {
        self.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
