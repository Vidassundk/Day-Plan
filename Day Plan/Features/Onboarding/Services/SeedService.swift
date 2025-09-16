import Foundation
import SwiftData
import SwiftUI

private typealias Gap = (start: Date, end: Date)

/// Creates a first week from onboarding answers with **non-overlapping** blocks.
/// All placements are anchored to a single day window and then copied as
/// `ScheduledPlan`s under the chosen templates.
@MainActor
struct SeedService {
    let context: ModelContext
    let calendar: Calendar = .current

    /// Stable palette for seeded plans (titles are the keys).
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
        // Plans library (find-or-create by (title, emoji) + color backfill)
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

        // Templates
        let workday = dayTemplate(named: "Workday")
        let weekend = dayTemplate(named: "Weekend")

        try? context.save()  // stabilize identities

        // SEEDING ORDER (prevents overlaps by design):
        // 1) Work/School anchors (foundation blocks)
        if s.workSchedule == .fixedNineToFive {
            addBlockNonOverlap(
                plan: work, to: workday, startHM: (9, 0), minutes: 8 * 60,
                bias: .preferAfter)
        }

        // 2) Movement
        switch s.movement {
        case .weekdays:
            // Prefer before work; if 7:00 conflicts, it slides earlier.
            addBlockNonOverlap(
                plan: workout, to: workday, startHM: (7, 0), minutes: 30,
                bias: .preferBefore)
        case .weekends:
            addBlockNonOverlap(
                plan: workout, to: weekend, startHM: (9, 0), minutes: 45,
                bias: .preferAfter)
        default:
            break
        }

        // 3) Fun anchor (1–2 placeholders)
        if let anchor = s.funAnchor {
            switch anchor {
            case .family:
                addFunAnchors(plan: family, workday: workday, weekend: weekend)
            case .friends:
                addFunAnchors(plan: friends, workday: workday, weekend: weekend)
            case .learning:
                addFunAnchors(plan: study, workday: workday, weekend: weekend)
            case .creative:
                addFunAnchors(
                    plan: creative, workday: workday, weekend: weekend)
            case .rest:
                addFunAnchors(plan: rest, workday: workday, weekend: weekend)
            }
        }

        // 4) Daily rhythm (placed after anchors so they slide intelligently)
        addDailyRhythmNonOverlap(to: workday, using: s)
        addDailyRhythmNonOverlap(to: weekend, using: s)

        // 5) Weekday assignments
        assign(
            workday, to: [.monday, .tuesday, .wednesday, .thursday, .friday])
        assign(weekend, to: [.saturday, .sunday])

        try? context.save()
    }
}

// MARK: - Non-overlap placement

extension SeedService {
    enum PlacementBias { case preferBefore, preferAfter }

    /// Place a block in the nearest available gap according to `bias`.
    fileprivate func addBlockNonOverlap(
        plan: Plan,
        to template: DayTemplate,
        startHM: (Int, Int),
        minutes: Int,
        bias: PlacementBias
    ) {
        let window = DayWindow.ofDay(containing: .now, calendar: calendar)
        let reqPicked =
            calendar.date(
                bySettingHour: startHM.0, minute: startHM.1, second: 0,
                of: window.start
            ) ?? window.start
        let requestedStart = TimeUtil.anchoredTime(
            reqPicked, to: window.start, calendar: calendar)

        // Clamp duration to the day (upper bound); we may clamp again after placement.
        let maxMinutes = DayScheduleEngine.clampDurationWithinDay(
            start: requestedStart, requestedMinutes: minutes, day: window)

        guard maxMinutes > 0 else { return }

        // Build free gaps for this template on the anchored day.
        let gaps = freeGaps(in: template, day: window)

        // If it already fits at the requested time, use it.
        if let g = gaps.first(where: {
            $0.start <= requestedStart
                && $0.end
                    >= requestedStart.addingTimeInterval(
                        TimeInterval(maxMinutes * 60))
        }) {
            insert(
                plan: plan, to: template, start: requestedStart,
                minutes: maxMinutes, within: window)
            return
        }

        // Try according to bias.
        if let placed = place(
            in: gaps, around: requestedStart, minutes: maxMinutes, bias: bias)
        {
            insert(
                plan: plan, to: template, start: placed, minutes: maxMinutes,
                within: window)
            return
        }

        // As a last resort, try shrinking to fit the nearest viable gap according to bias.
        if let (gap, shrunkenMinutes) = shrinkToFit(
            in: gaps, around: requestedStart, minutes: maxMinutes, bias: bias),
            shrunkenMinutes > 0
        {
            insert(
                plan: plan, to: template, start: gap, minutes: shrunkenMinutes,
                within: window)
        }
    }

    // Build free gaps
    private func freeGaps(in template: DayTemplate, day: DayWindow) -> [Gap] {
        let intervals: [(Date, Date)] = template.scheduledPlans.map { sp in
            let s = TimeUtil.anchoredTime(
                sp.startTime, to: day.start, calendar: calendar)
            let e = min(day.end, s.addingTimeInterval(sp.duration))
            return (s, e)
        }.sorted(by: { $0.0 < $1.0 })

        var gaps: [Gap] = []
        var cursor = day.start
        for (s, e) in intervals {
            if s > cursor { gaps.append((start: cursor, end: s)) }
            cursor = max(cursor, e)
        }
        if cursor < day.end { gaps.append((start: cursor, end: day.end)) }
        return gaps
    }

    private func place(
        in gaps: [Gap], around requested: Date, minutes: Int,
        bias: PlacementBias
    ) -> Date? {
        let dur = TimeInterval(minutes * 60)

        func fits(_ g: Gap, start: Date) -> Bool {
            start >= g.start && start.addingTimeInterval(dur) <= g.end
        }

        if let g = gaps.first(where: {
            $0.start <= requested && $0.end >= requested.addingTimeInterval(dur)
        }) {
            return requested.clamped(to: g, duration: dur)
        }

        switch bias {
        case .preferBefore:
            if let g = gaps.last(where: {
                $0.end <= requested && $0.end.timeIntervalSince($0.start) >= dur
            }) {
                let start = g.end.addingTimeInterval(-dur)
                return fits(g, start: start) ? start : nil
            }
            if let g = gaps.first(where: {
                $0.start >= requested
                    && $0.end.timeIntervalSince($0.start) >= dur
            }) {
                return g.start
            }
        case .preferAfter:
            if let g = gaps.first(where: {
                $0.start >= requested
                    && $0.end.timeIntervalSince($0.start) >= dur
            }) {
                return g.start
            }
            if let g = gaps.last(where: {
                $0.end <= requested && $0.end.timeIntervalSince($0.start) >= dur
            }) {
                return g.end.addingTimeInterval(-dur)
            }
        }
        return nil
    }

    private func shrinkToFit(
        in gaps: [Gap], around requested: Date, minutes: Int,
        bias: PlacementBias
    ) -> (Date, Int)? {
        func length(_ g: Gap) -> Int {
            max(0, Int(g.end.timeIntervalSince(g.start) / 60))
        }

        switch bias {
        case .preferBefore:
            if let g = gaps.last(where: { $0.end <= requested }) {
                let m = length(g)
                if m > 0 {
                    return (g.end.addingTimeInterval(TimeInterval(-m * 60)), m)
                }
            }
            if let g = gaps.first(where: { $0.start >= requested }) {
                let m = length(g)
                if m > 0 { return (g.start, m) }
            }
        case .preferAfter:
            if let g = gaps.first(where: { $0.start >= requested }) {
                let m = length(g)
                if m > 0 { return (g.start, m) }
            }
            if let g = gaps.last(where: { $0.end <= requested }) {
                let m = length(g)
                if m > 0 {
                    return (g.end.addingTimeInterval(TimeInterval(-m * 60)), m)
                }
            }
        }
        return nil
    }

    private func insert(
        plan: Plan,
        to template: DayTemplate,
        start: Date,
        minutes: Int,
        within day: DayWindow
    ) {
        // Final clamp in case placement touches the day boundary.
        let finalMinutes = DayScheduleEngine.clampDurationWithinDay(
            start: start, requestedMinutes: minutes, day: day)

        guard finalMinutes > 0 else { return }

        let sp = ScheduledPlan(
            plan: plan, startTime: start,
            duration: TimeInterval(finalMinutes * 60))
        sp.dayTemplate = template
        context.insert(sp)
    }
}

// MARK: - Builders

extension SeedService {
    fileprivate func plan(title: String, emoji: String) -> Plan {
        if let existing = context.plans().first(where: {
            $0.title == title && $0.emoji == emoji
        }) {
            if existing.colorHex.isEmpty, let hex = seedHex[title] {
                existing.colorHex = hex
            }
            return existing
        }
        let hex = seedHex[title] ?? ""
        let p = Plan(
            title: title, planDescription: nil, emoji: emoji, colorHex: hex)
        context.insert(p)
        return p
    }

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

    fileprivate func addDailyRhythmNonOverlap(
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
            sleepStartHM = (0, 0)
        }

        let prep = plan(title: "Morning Prep", emoji: "🧼")
        let wind = plan(title: "Wind Down", emoji: "🌙")
        let sleep = plan(title: "Sleep", emoji: "😴")

        // Morning prep wants to be **before** any morning anchor like Work.
        addBlockNonOverlap(
            plan: prep, to: template, startHM: morningStartHM, minutes: 30,
            bias: .preferBefore)

        // Evening blocks prefer to stay **after** their requested time.
        addBlockNonOverlap(
            plan: wind, to: template, startHM: windStartHM, minutes: 45,
            bias: .preferAfter)
        addBlockNonOverlap(
            plan: sleep, to: template, startHM: sleepStartHM, minutes: 8 * 60,
            bias: .preferAfter)
    }

    fileprivate func addFunAnchors(
        plan: Plan, workday: DayTemplate, weekend: DayTemplate
    ) {
        addBlockNonOverlap(
            plan: plan, to: workday, startHM: (19, 0), minutes: 60,
            bias: .preferAfter)
        addBlockNonOverlap(
            plan: plan, to: weekend, startHM: (10, 0), minutes: 90,
            bias: .preferAfter)
    }

    fileprivate func assign(_ template: DayTemplate, to weekdays: [Weekday]) {
        for w in weekdays where context.assignment(for: w) == nil {
            context.insert(WeekdayAssignment(weekday: w, template: template))
        }
    }
}

// MARK: - Small helpers

extension Date {
    fileprivate func clamped(to gap: Gap, duration: TimeInterval) -> Date {
        let latestStart = gap.end.addingTimeInterval(-duration)
        let candidate = max(self, gap.start)
        return candidate <= latestStart ? candidate : latestStart
    }
}
