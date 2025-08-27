//
//  WeekdayAssignment.swift
//  Day Plan
//
//  Created by Vidas Sun on 27/08/2025.
//

import Foundation
import SwiftData

@Model
final class WeekdayAssignment {
    // One row per weekday; uniqueness guarantees only one template per weekday
    @Attribute(.unique) var weekdayRaw: Int

    // Optional so a weekday can be “unassigned”
    @Relationship(deleteRule: .nullify) var template: DayTemplate?

    init(weekday: Weekday, template: DayTemplate? = nil) {
        self.weekdayRaw = weekday.rawValue
        self.template = template
    }

    var weekday: Weekday {
        get { Weekday(rawValue: weekdayRaw) ?? .monday }
        set { weekdayRaw = newValue.rawValue }
    }
}
