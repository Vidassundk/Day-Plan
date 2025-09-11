import Foundation
import SwiftData
import SwiftUI

/// Creates an immediately useful week from onboarding answers.
/// Runs on the MainActor (reads `OnboardingStateStore`, uses `ModelContext` on main).
///
/// Design:
/// - **Idempotent enough for first-run:** find-or-create by (title, emoji).
/// - **Single-day correctness:** uses DayWindow/TimeUtil/Engine to anchor + clamp.
/// - **Readable data:** seeded plans get stable colors so the timeline feels alive.
@MainActor
struct SeedService {
    let context: ModelContext
    let calendar: Calendar = .current

    /// Stable palette for seeded plans (titles are the keys).
    /// Tip: if you localize titles later, switch to a non-localized key map.
    private let seedHex: [String: String] = [
        "Work": "#4A90E2",
        "Morning Prep": "#2AB0A1",
        "Wind Down": "#8B5CF6",
        "Sleep": "#0EA5E9",
        "Workout": "#22C55E",
        "Learning": "#F59E0B",
        "Creative": "#EC4899",
        "Family": "#EAB308",
        "Friends": "#06B6D4",
        "Rest": "#94A3B8",
    ]

    // MARK: - Public entry

    func generate(using s: OnboardingStateStore) {
        // 1) Plans library (find-or-create by (title, emoji) + color backfill)
        let work = plan(title: "Work", emoji: "💼")
        let prep = plan(title: "Morning Prep", emoji: "🧼")
        let wind = plan(title: "Wind Down", emoji: "🌙")
        let sleep = plan(title: "Sleep", emoji: "😴")

        let workout = plan(title: "Workout", emoji: "🏋️")
        let study = plan(title: "Learning", emoji: "📚")
        let creative = plan(title: "Creative", emoji: "🎨")
        let family = plan(title: "Family", emoji: "👨‍👩‍👧‍👦")
        let friends = plan(title: "Friends", emoji: "🧑‍🤝‍🧑")
        let rest = plan(title: "Rest", emoji: "🛋️")

        // 2) Build templates (Mon–Fri “Workday”, Sat–Sun “Weekend”)
        let workday = dayTemplate(named: "Workday")
        let weekend = dayTemplate(named: "Weekend")

        // Stabilize object identities before wiring many relationships.
        try? context.save()

        // 3) Daily rhythm → add morning prep + wind down + sleep to both templates
        addDailyRhythm(to: workday, using: s)
        addDailyRhythm(to: weekend, using: s)

        // 4) Work/School
        if s.workSchedule == .fixedNineToFive {
            addBlock(plan: work, to: workday, startHM: (9, 0), minutes: 8 * 60)
        }
        // “Yes, but different” → leave a placeholder later if you want.

        // 5) Movement
        switch s.movement {
        case .weekdays:
            addBlock(plan: workout, to: workday, startHM: (7, 0), minutes: 30)
        case .weekends:
            addBlock(plan: workout, to: weekend, startHM: (9, 0), minutes: 45)
        default:
            break
        }

        // 6) Fun anchor (1–2 placeholders)
        if let anchor = s.funAnchor {
            switch anchor {
            case .family:
                addAnchorBlocks(
                    plan: family, workday: workday, weekend: weekend)
            case .friends:
                addAnchorBlocks(
                    plan: friends, workday: workday, weekend: weekend)
            case .learning:
                addAnchorBlocks(plan: study, workday: workday, weekend: weekend)
            case .creative:
                addAnchorBlocks(
                    plan: creative, workday: workday, weekend: weekend)
            case .rest:
                addAnchorBlocks(plan: rest, workday: workday, weekend: weekend)
            }
        }

        // 7) Assign templates to weekdays (don’t overwrite existing assignments)
        assign(
            workday, to: [.monday, .tuesday, .wednesday, .thursday, .friday])
        assign(weekend, to: [.saturday, .sunday])

        // 8) Save once
        try? context.save()
    }
}

// MARK: - Builders

extension SeedService {
    /// Find-or-create a Plan by (title, emoji).
    /// If found but color is empty, one-time backfill from `seedHex`.
    fileprivate func plan(title: String, emoji: String) -> Plan {
        if let existing = context.plans().first(where: {
            $0.title == title && $0.emoji == emoji
        }) {
            if existing.colorHex.isEmpty, let hex = seedHex[title] {
                existing.colorHex = hex
            }
            return existing
        }
        let hex = seedHex[title] ?? ""  // empty → accent fallback (acceptable if not in palette)
        let p = Plan(
            title: title, planDescription: nil, emoji: emoji, colorHex: hex)
        context.insert(p)
        return p
    }

    /// Find-or-create a DayTemplate by name.
    fileprivate func dayTemplate(named name: String) -> DayTemplate {
        if let existing = context.dayTemplates().first(where: {
            $0.name == name
        }) {
            return existing
        }
        let t = DayTemplate(name: name)
        context.insert(t)
        return t
    }

    /// Add morning prep + wind down + sleep according to chosen bands.
    /// Uses engine helpers to ensure we never spill past midnight.
    fileprivate func addDailyRhythm(
        to template: DayTemplate, using s: OnboardingStateStore
    ) {
        // Morning start by band
        let morningStartHM: (Int, Int)
        switch s.startBand {
        case .fiveToSix: morningStartHM = (5, 30)
        case .sevenToEight: morningStartHM = (7, 0)
        case .nineToTen: morningStartHM = (9, 0)
        case .later, .none: morningStartHM = (10, 0)
        }

        // Evening wind-down + sleep by band
        let windStartHM: (Int, Int)
        let sleepStartHM: (Int, Int)
        switch s.endBand {
        case .nineToTen:
            windStartHM = (21, 15)
            sleepStartHM = (22, 30)
        case .elevenToMidnight:
            windStartHM = (22, 15)
            sleepStartHM = (23, 30)
        case .afterMidnight, .none:
            windStartHM = (23, 15)
            sleepStartHM = (0, 0)  // clamps at midnight
        }

        let prep = plan(title: "Morning Prep", emoji: "🧼")
        let wind = plan(title: "Wind Down", emoji: "🌙")
        let sleep = plan(title: "Sleep", emoji: "😴")

        addBlock(plan: prep, to: template, startHM: morningStartHM, minutes: 30)
        addBlock(plan: wind, to: template, startHM: windStartHM, minutes: 45)
        addBlock(
            plan: sleep, to: template, startHM: sleepStartHM, minutes: 8 * 60)  // truncates at 24:00
    }

    /// Evenings on workdays; a longer slot on weekends for variety.
    fileprivate func addAnchorBlocks(
        plan: Plan, workday: DayTemplate, weekend: DayTemplate
    ) {
        addBlock(plan: plan, to: workday, startHM: (19, 0), minutes: 60)
        addBlock(plan: plan, to: weekend, startHM: (10, 0), minutes: 90)
    }

    /// Place a plan into a template using strict day anchoring and clamping.
    fileprivate func addBlock(
        plan: Plan, to template: DayTemplate, startHM: (Int, Int), minutes: Int
    ) {
        let window = DayWindow.ofDay(containing: .now, calendar: calendar)
        let picked =
            calendar.date(
                bySettingHour: startHM.0, minute: startHM.1, second: 0,
                of: window.start) ?? window.start
        let start = TimeUtil.anchoredTime(
            picked, to: window.start, calendar: calendar)
        let clamped = DayScheduleEngine.clampDurationWithinDay(
            start: start, requestedMinutes: minutes, day: window)

        let sp = ScheduledPlan(
            plan: plan, startTime: start, duration: TimeInterval(clamped * 60))
        sp.dayTemplate = template
        context.insert(sp)
    }

    /// Assign a template to a list of weekdays if not already assigned.
    fileprivate func assign(_ template: DayTemplate, to weekdays: [Weekday]) {
        for w in weekdays where context.assignment(for: w) == nil {
            // Your model initializer signature is (weekday:template:)
            let a = WeekdayAssignment(weekday: w, template: template)
            context.insert(a)
        }
    }
}
