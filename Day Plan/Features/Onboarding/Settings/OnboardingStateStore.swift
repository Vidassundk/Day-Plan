import Foundation
import SwiftUI

/// Tiny source of truth for onboarding progress + user choices.
/// - We keep it simple with @AppStorage so the first-run logic
///   works before SwiftData containers are ready.
/// - If you later want multi-profile or syncing, you can move this to SwiftData.
@MainActor
final class OnboardingStateStore: ObservableObject {
    @AppStorage("onboarding.completed") var hasCompletedOnboarding: Bool = false
    @AppStorage("onboarding.seedVersion") var seedVersion: Int = 1

    // Answers captured in the wizard (persisted so the user can resume).
    @AppStorage("onboarding.dailyRhythm.startBand") var startBandRaw: String =
        ""
    @AppStorage("onboarding.dailyRhythm.endBand") var endBandRaw: String = ""
    @AppStorage("onboarding.workSchedule") var workScheduleRaw: String = ""
    @AppStorage("onboarding.movement") var movementRaw: String = ""
    @AppStorage("onboarding.funAnchor") var funAnchorRaw: String = ""

    // Convenience accessors with enums
    var startBand: DailyStartBand? { DailyStartBand(rawValue: startBandRaw) }
    var endBand: DailyEndBand? { DailyEndBand(rawValue: endBandRaw) }
    var workSchedule: WorkSchedule? { WorkSchedule(rawValue: workScheduleRaw) }
    var movement: MovementHabit? { MovementHabit(rawValue: movementRaw) }
    var funAnchor: FunAnchor? { FunAnchor(rawValue: funAnchorRaw) }

    func reset() {
        hasCompletedOnboarding = false
        seedVersion = 1
        startBandRaw = ""
        endBandRaw = ""
        workScheduleRaw = ""
        movementRaw = ""
        funAnchorRaw = ""
    }
}

/// Answer enums (kept small + string-backed so they serialize cleanly)
enum DailyStartBand: String, CaseIterable {
    case fiveToSix = "5–6am"
    case sevenToEight = "7–8am"
    case nineToTen = "9–10am"
    case later = "Later"
}

enum DailyEndBand: String, CaseIterable {
    case nineToTen = "9–10pm"
    case elevenToMidnight = "11pm–12am"
    case afterMidnight = "After midnight"
}

enum WorkSchedule: String, CaseIterable {
    case fixedNineToFive = "Fixed 9–5 (Mon–Fri)"
    case fixedOtherAddLater = "Yes, but different → Add later"
    case none = "No"
}

enum MovementHabit: String, CaseIterable {
    case weekdays
    case weekends
    case none
}

enum FunAnchor: String, CaseIterable {
    case family, friends, learning, creative, rest
}
