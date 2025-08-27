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

// MARK: - 24h Day window
public struct DayWindow {
    public let start: Date
    public var end: Date { start.addingTimeInterval(24 * 60 * 60) }
    public init(start: Date) { self.start = start }
}

// MARK: - Schedule engine (generic over item type)
public enum DayScheduleEngine {
    /// End of the last block inside the day, walking items in start order.
    public static func earliestAvailableStart<T>(
        day: DayWindow,
        items: [T],
        getStart: (T) -> Date,
        getDuration: (T) -> TimeInterval
    ) -> Date {
        var cursor = day.start
        let sorted = items.sorted { getStart($0) < getStart($1) }
        for item in sorted {
            let s = max(
                TimeUtil.anchoredTime(getStart(item), to: day.start), cursor)
            let e = s.addingTimeInterval(getDuration(item))
            cursor = max(cursor, e)
        }
        return min(cursor, day.end)
    }

    /// Minutes remaining until day end after current items.
    public static func remainingMinutes<T>(
        day: DayWindow,
        items: [T],
        getStart: (T) -> Date,
        getDuration: (T) -> TimeInterval
    ) -> Int {
        let usedEnd = earliestAvailableStart(
            day: day, items: items, getStart: getStart, getDuration: getDuration
        )
        return max(0, Int(day.end.timeIntervalSince(usedEnd) / 60))
    }

    /// Clamp a requested length so that `start + length` stays <= day.end. Guarantees >= 5 min when non-zero time left.
    public static func clampDurationWithinDay(
        start: Date, requestedMinutes: Int, day: DayWindow
    ) -> Int {
        guard start < day.end else { return 0 }
        let maxAllowed = Int(day.end.timeIntervalSince(start) / 60)
        return max(0, min(maxAllowed, max(5, requestedMinutes)))
    }

    /// Reflow a set of items to obey: first start >= day.start, each next start >= previous end, and all within the 24h window.
    /// Works for both value (struct) and reference (class) items.
    public static func reflow<T>(
        day: DayWindow,
        items: [T],
        getStart: (T) -> Date,
        getDuration: (T) -> TimeInterval,
        setStart: (inout T, Date) -> Void,
        setDuration: (inout T, TimeInterval) -> Void
    ) -> [T] {
        var cursor = day.start
        let sorted = items.sorted { getStart($0) < getStart($1) }
        var out: [T] = []
        for var item in sorted {
            let desired = TimeUtil.anchoredTime(getStart(item), to: day.start)
            let start = max(desired, cursor)
            var duration = getDuration(item)
            let maxAllowed = day.end.timeIntervalSince(start)
            if duration > maxAllowed { duration = max(0, maxAllowed) }
            setStart(&item, start)
            setDuration(&item, duration)
            cursor = start.addingTimeInterval(duration)
            out.append(item)
        }
        return out
    }
}

// MARK: - Small convenience for models (non-invasive)
extension Date {
    /// Convenience to add minutes using Calendar.
    public func adding(minutes: Int) -> Date {
        self.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
