//
//  Weekday.swift
//  Day Plan
//
//  Created by Vidas Sun on 27/08/2025.
//

import Foundation

public enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case monday = 1
    case tuesday, wednesday, thursday, friday, saturday, sunday

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    public static var ordered: [Weekday] { Self.allCases }
}
