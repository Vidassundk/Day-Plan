import Foundation

/// Time helpers used across timeline, editors, and validation flows.
public enum TimeUtil {
    /// Apply hour:minute:second of `time` onto the **date** of `anchor`.
    /// Useful for keeping a chosen time while shifting it into a specific day.
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

/// Represents a 24-hour window starting at `start`.
public struct DayWindow {
    public let start: Date
    public var end: Date { start.addingTimeInterval(24 * 60 * 60) }

    public init(start: Date) { self.start = start }
}

/// Operations that keep schedules within a single-day boundary.
public enum DayScheduleEngine {
    /// Clamp a requested duration (in minutes) so that `start + duration` does not exceed `day.end`.
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
    /// Add minutes to a `Date` using `TimeInterval`.
    public func adding(minutes: Int) -> Date {
        self.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
