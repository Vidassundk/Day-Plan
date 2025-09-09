import Foundation

/// Deterministic date builders (UTC / Gregorian) so tests don't depend on device timezone.
enum FixedDates {
    static var tzUTC: TimeZone { TimeZone(secondsFromGMT: 0)! }

    static func make(
        _ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0
    ) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tzUTC
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        c.hour = h
        c.minute = min
        c.second = s
        return cal.date(from: c)!
    }

    static let jan1 = make(2025, 1, 1, 0, 0, 0)
    static let jan1_0900 = make(2025, 1, 1, 9, 0, 0)
    static let jan1_1000 = make(2025, 1, 1, 10, 0, 0)
    static let jan1_1100 = make(2025, 1, 1, 11, 0, 0)
    static let jan1_2300 = make(2025, 1, 1, 23, 0, 0)
    static let jan2 = make(2025, 1, 2, 0, 0, 0)
    static let jan2_1545 = make(2025, 1, 2, 15, 45, 0)
}
