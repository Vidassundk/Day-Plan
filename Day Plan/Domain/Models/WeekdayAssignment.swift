import Foundation
import SwiftData

/// One row per weekday indicating which `DayTemplate` is assigned.
/// Unique key on `weekdayRaw` ensures at most one template per weekday.
@Model
final class WeekdayAssignment {
    @Attribute(.unique) var weekdayRaw: Int

    /// Optional so a weekday can be left “unassigned”.
    @Relationship(deleteRule: .nullify) var template: DayTemplate?

    init(weekday: Weekday, template: DayTemplate? = nil) {
        self.weekdayRaw = weekday.rawValue
        self.template = template
    }

    /// Strongly-typed accessor bridging `weekdayRaw` <-> `Weekday`.
    var weekday: Weekday {
        get { Weekday(rawValue: weekdayRaw) ?? .monday }
        set { weekdayRaw = newValue.rawValue }
    }
}
