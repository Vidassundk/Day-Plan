import Foundation

// MARK: - Time utilities
public enum TimeUtil {
    /// Return `time` with only its hour/minute/second applied onto the date of `anchor`.
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

    /// Human-readable minutes → "xh ym" / "xm".
    public static func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

public struct DayWindow {
    public let start: Date
    public var end: Date { start.addingTimeInterval(24 * 60 * 60) }
}

public enum DayScheduleEngine {
    /// Clamp so that (start + length) <= day.start + 24h
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

// MARK: - Small convenience for models (non-invasive)
extension Date {
    /// Convenience to add minutes using Calendar.
    public func adding(minutes: Int) -> Date {
        self.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
