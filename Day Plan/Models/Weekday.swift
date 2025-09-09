import Foundation

/// ISO-like weekday (Mon=1). Codable for persistence and settings.
public enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case monday = 1
    case tuesday, wednesday, thursday, friday, saturday, sunday

    public var id: Int { rawValue }

    /// Localizable display name for UI.
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

    /// Monday-first ordering for list UIs and pickers.
    public static var ordered: [Weekday] { Self.allCases }
}
