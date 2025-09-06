// ContentView.swift (updated)
// Focus strictly on the timeline; CRUD moved to DayTemplateManagerView.
// Use direct NavigationLinks (no typed NavigationPath) to avoid path type mismatches.

import Foundation
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Data used only for today's mapping
    @Query private var assignments: [WeekdayAssignment]

    var body: some View {
        NavigationStack {
            List {
                // MARK: Today
                Section {
                    if let template = todaysTemplate {
                        TodayTimelineView(templateID: template.id)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No template assigned for today.")
                                .foregroundStyle(.secondary)
                            NavigationLink {
                                WeekScheduleView()
                            } label: {
                                Label(
                                    "Assign a template",
                                    systemImage: "calendar.badge.clock")
                            }
                        }
                    }
                }
            }
            .navigationTitle(today.name)
            .toolbar {
                // Week schedule (kept here because it affects today’s timeline)
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        WeekScheduleView()
                    } label: {
                        Label(
                            "Week Schedule", systemImage: "calendar.badge.clock"
                        )
                    }
                }
                // Navigate to the new Manager screen
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        DayTemplateManagerView()
                    } label: {
                        Label(
                            "Manage Templates",
                            systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
    }

    // MARK: - Today helpers

    private var today: Weekday {
        // Map Apple’s Sunday=1...Saturday=7 to our Monday=1...Sunday=7
        let wd = Calendar.current.component(.weekday, from: Date())  // 1...7 (Sun=1)
        let mondayBased = ((wd + 5) % 7) + 1  // Mon=1 ... Sun=7
        return Weekday(rawValue: mondayBased) ?? .monday
    }

    private var todaysTemplate: DayTemplate? {
        assignments.first(where: { $0.weekdayRaw == today.rawValue })?.template
    }
}
#if DEBUG
    import SwiftUI
    import SwiftData

    private enum PreviewPalette {
        // small, high-contrast set; reuse via modulo
        static let base8: [String] = [
            "#1E88E5", "#8E24AA", "#43A047", "#FB8C00",
            "#F4511E", "#3949AB", "#26A69A", "#AB47BC",
        ]
    }

    // MARK: - Helpers shared by previews
    @MainActor
    private func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: DayTemplate.self,
            ScheduledPlan.self,
            Plan.self,
            WeekdayAssignment.self,
            configurations: config
        )
    }

    private func assignToday(_ tpl: DayTemplate, using cal: Calendar = .current)
        -> WeekdayAssignment
    {
        // Map Apple weekday (1=Sun...7=Sat) -> your enum (likely Monday-based)
        let today = Date()
        let wdApple = cal.component(.weekday, from: today)  // 1...7
        let mondayBased = ((wdApple + 5) % 7) + 1  // 1...7 starting Monday
        let weekday = Weekday(rawValue: mondayBased) ?? .monday
        return WeekdayAssignment(weekday: weekday, template: tpl)
    }

    // MARK: - Preview A — Small, no overlap
    struct ContentView_NoOverlap_Previews: PreviewProvider {
        static let container: ModelContainer = {
            let c = makeInMemoryContainer()
            seed_NoOverlap(into: c)
            return c
        }()

        static var previews: some View {
            ContentView()
                .modelContainer(container)
                .previewDisplayName(
                    "ContentView — No Overlap (3 plans, colored)")
        }

        @MainActor
        private static func seed_NoOverlap(into container: ModelContainer) {
            let ctx = container.mainContext
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: Date())

            // Plans
            let a = Plan(
                title: "Standup", planDescription: "Sprint 42", emoji: "👥")
            let b = Plan(
                title: "Design Review", planDescription: "UI polish", emoji: "🎨"
            )
            let c = Plan(
                title: "Deep Work", planDescription: "Feature branch",
                emoji: "💻")

            // Hard-coded colors
            a.colorHex = "#1E88E5"  // blue
            b.colorHex = "#43A047"  // green
            c.colorHex = "#FB8C00"  // orange

            // Times
            let s0 = cal.date(
                bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
            let s1 = cal.date(byAdding: .minute, value: 60, to: s0)!
            let s2 = cal.date(byAdding: .minute, value: 60, to: s1)!

            // Blocks
            let sp0 = ScheduledPlan(plan: a, startTime: s0, duration: 55 * 60)
            let sp1 = ScheduledPlan(plan: b, startTime: s1, duration: 45 * 60)
            let sp2 = ScheduledPlan(plan: c, startTime: s2, duration: 60 * 60)

            // Template + assignment
            let tpl = DayTemplate(name: "Workday", startTime: startOfDay)
            tpl.scheduledPlans = [sp0, sp1, sp2]
            let assignment = assignToday(tpl)

            [a, b, c].forEach { ctx.insert($0) }
            [sp0, sp1, sp2].forEach { ctx.insert($0) }
            ctx.insert(tpl)
            ctx.insert(assignment)
            try? ctx.save()
        }
    }

    // MARK: - Preview B — Light overlaps, concise palette
    struct ContentView_Overlap_Previews: PreviewProvider {
        static let container: ModelContainer = {
            let c = makeInMemoryContainer()
            seed_Overlap(into: c)
            return c
        }()

        static var previews: some View {
            ContentView()
                .modelContainer(container)
                .previewDisplayName("ContentView — Overlaps (8 plans, colored)")
        }

        @MainActor
        private static func seed_Overlap(into container: ModelContainer) {
            let ctx = container.mainContext
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: Date())

            func at(_ h: Int, _ m: Int = 0) -> Date {
                cal.date(
                    bySettingHour: h, minute: m, second: 0, of: startOfDay)!
            }
            func mins(_ m: Int) -> TimeInterval { TimeInterval(m * 60) }

            // 16 plans (compact labels, good variety)
            let wake = Plan(
                title: "Wake & Stretch", planDescription: "Light mobility",
                emoji: "🌅")
            let coffee = Plan(
                title: "Coffee", planDescription: "Dial in grind", emoji: "☕️")
            let emails = Plan(
                title: "Emails", planDescription: "Triage inbox", emoji: "📨")
            let standup = Plan(
                title: "Standup", planDescription: "Daily sync", emoji: "👥")
            let planning = Plan(
                title: "Planning", planDescription: "Today’s tasks", emoji: "🗂️")
            let deepAM = Plan(
                title: "Deep Work A", planDescription: "Feature X", emoji: "💻")
            let design = Plan(
                title: "Design Review", planDescription: "UI polish", emoji: "🎨"
            )
            let lunch = Plan(
                title: "Lunch", planDescription: "Quick bite", emoji: "🥗")
            let walk = Plan(
                title: "Walk", planDescription: "10–15 min", emoji: "🚶")
            let pairing = Plan(
                title: "Pairing", planDescription: "Debug together", emoji: "🤝")
            let review = Plan(
                title: "Code Review", planDescription: "PRs / QA", emoji: "🔍")
            let client = Plan(
                title: "Client Project", planDescription: "Milestone",
                emoji: "🏗️")
            let deepPM = Plan(
                title: "Deep Work B", planDescription: "Refactor", emoji: "🧠")
            let gym = Plan(
                title: "Gym", planDescription: "Pull day", emoji: "🏋️")
            let groceries = Plan(
                title: "Groceries", planDescription: "Market run", emoji: "🛒")
            let windDown = Plan(
                title: "Wind Down", planDescription: "Read & prep", emoji: "🛌")

            // Palette (high-contrast, loops if more plans than colors)
            let colors: [String] = PreviewPalette.base8
            let plans = [
                wake, coffee, emails, standup, planning, deepAM, design, lunch,
                walk, pairing, review, client, deepPM, gym, groceries, windDown,
            ]
            for (i, p) in plans.enumerated() {
                p.colorHex = colors[i % colors.count]
            }

            // Schedule (light overlaps throughout the day)
            let blocks: [ScheduledPlan] = [
                ScheduledPlan(
                    plan: wake, startTime: at(6, 45), duration: mins(20)),
                ScheduledPlan(
                    plan: coffee, startTime: at(7, 5), duration: mins(15)),
                ScheduledPlan(
                    plan: emails, startTime: at(8, 0), duration: mins(40)),
                ScheduledPlan(
                    plan: standup, startTime: at(9, 0), duration: mins(30)),
                ScheduledPlan(
                    plan: planning, startTime: at(9, 15), duration: mins(45)),  // overlaps standup a bit
                ScheduledPlan(
                    plan: deepAM, startTime: at(9, 45), duration: mins(120)),
                ScheduledPlan(
                    plan: design, startTime: at(10, 30), duration: mins(50)),  // overlaps deepAM
                ScheduledPlan(
                    plan: lunch, startTime: at(12, 0), duration: mins(45)),
                ScheduledPlan(
                    plan: walk, startTime: at(12, 30), duration: mins(20)),  // overlaps lunch tail
                ScheduledPlan(
                    plan: pairing, startTime: at(13, 0), duration: mins(45)),
                ScheduledPlan(
                    plan: review, startTime: at(13, 30), duration: mins(60)),  // overlaps pairing
                ScheduledPlan(
                    plan: client, startTime: at(14, 30), duration: mins(90)),
                ScheduledPlan(
                    plan: deepPM, startTime: at(15, 30), duration: mins(75)),  // overlaps client
                ScheduledPlan(
                    plan: gym, startTime: at(18, 0), duration: mins(60)),
                ScheduledPlan(
                    plan: groceries, startTime: at(19, 15), duration: mins(35)),
                ScheduledPlan(
                    plan: windDown, startTime: at(21, 0), duration: mins(45)),
            ]

            let tpl = DayTemplate(
                name: "Overlap Day (Expanded)", startTime: startOfDay)
            tpl.scheduledPlans = blocks
            let assignment = assignToday(tpl)

            plans.forEach { ctx.insert($0) }
            blocks.forEach { ctx.insert($0) }
            ctx.insert(tpl)
            ctx.insert(assignment)
            try? ctx.save()
        }
    }
#endif
