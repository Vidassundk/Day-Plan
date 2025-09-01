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
                        TodayTimelineView(template: template)
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

    struct ContentView_FullDemo_Previews: PreviewProvider {
        static var previews: some View {
            let schema = Schema([
                DayTemplate.self,
                ScheduledPlan.self,
                Plan.self,
                WeekdayAssignment.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(
                for: schema, configurations: config)

            seedDemoData_NoOverlap(into: container)

            return ContentView()
                .modelContainer(container)
                .previewDisplayName("ContentView — No Overlap (baseline)")
        }

        private static func seedDemoData_NoOverlap(
            into container: ModelContainer
        ) {
            let ctx = container.mainContext
            let cal = Calendar.current
            let now = Date()
            let startOfDay = cal.startOfDay(for: now)

            let a = Plan(
                title: "Standup", planDescription: "Sprint 42", emoji: "👥")
            let b = Plan(
                title: "Design Review", planDescription: "UI polish", emoji: "🎨"
            )
            let c = Plan(
                title: "Deep Work", planDescription: "Feature branch",
                emoji: "💻")

            let s0 = cal.date(byAdding: .hour, value: 9, to: startOfDay)!
            let s1 = cal.date(byAdding: .minute, value: 60, to: s0)!
            let s2 = cal.date(byAdding: .minute, value: 60, to: s1)!

            let sp0 = ScheduledPlan(plan: a, startTime: s0, duration: 55 * 60)
            let sp1 = ScheduledPlan(plan: b, startTime: s1, duration: 45 * 60)
            let sp2 = ScheduledPlan(plan: c, startTime: s2, duration: 60 * 60)

            let tpl = DayTemplate(name: "Workday", startTime: startOfDay)
            tpl.scheduledPlans = [sp0, sp1, sp2]

            let wdApple = cal.component(.weekday, from: now)
            let mondayBased = ((wdApple + 5) % 7) + 1
            let weekday = Weekday(rawValue: mondayBased) ?? .monday
            let assignment = WeekdayAssignment(weekday: weekday, template: tpl)

            [a, b, c].forEach { ctx.insert($0) }
            [sp0, sp1, sp2].forEach { ctx.insert($0) }
            ctx.insert(tpl)
            ctx.insert(assignment)
            try? ctx.save()
        }
    }

    struct ContentView_Overlap_Previews: PreviewProvider {
        static var previews: some View {
            let schema = Schema([
                DayTemplate.self,
                ScheduledPlan.self,
                Plan.self,
                WeekdayAssignment.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(
                for: schema, configurations: config)

            seedDemoData_WithOverlaps(into: container)

            return ContentView()
                .modelContainer(container)
                .previewDisplayName(
                    "ContentView — Overlapping Times (Full Day)")
        }

        /// Seeds a **full day** with intentional overlaps to exercise timeline rendering thoroughly.
        private static func seedDemoData_WithOverlaps(
            into container: ModelContainer
        ) {
            let ctx = container.mainContext
            let cal = Calendar.current
            let now = Date()
            let startOfDay = cal.startOfDay(for: now)

            // Helper for clock times & durations
            func at(_ h: Int, _ m: Int = 0) -> Date {
                cal.date(
                    bySettingHour: h, minute: m, second: 0, of: startOfDay)!
            }
            func mins(_ m: Int) -> TimeInterval { TimeInterval(m * 60) }

            // Plans
            let morning = Plan(
                title: "Morning Routine", planDescription: "Wash up, stretch",
                emoji: "🌅")
            let breakfast = Plan(
                title: "Breakfast", planDescription: "Oats & coffee", emoji: "🍳"
            )
            let podcast = Plan(
                title: "Podcast", planDescription: "Tech news", emoji: "🎧")
            let commute = Plan(
                title: "Commute", planDescription: "Bus + walk", emoji: "🚌")
            let emails = Plan(
                title: "Inbox Sweep", planDescription: "Zero-ish", emoji: "📨")
            let standup = Plan(
                title: "Standup", planDescription: "Sprint sync", emoji: "👥")
            let oneOnOne = Plan(
                title: "1:1", planDescription: "Mentoring", emoji: "🧭")
            let deep = Plan(
                title: "Deep Work", planDescription: "Feature X", emoji: "💻")
            let prReview = Plan(
                title: "PR Review", planDescription: "Queue", emoji: "🔍")
            let designRev = Plan(
                title: "Design Review", planDescription: "UI polish", emoji: "🎨"
            )
            let lunch = Plan(
                title: "Lunch", planDescription: "Salad run", emoji: "🥗")
            let walk = Plan(
                title: "Walk", planDescription: "Get steps", emoji: "🚶")
            let feature = Plan(
                title: "Feature Build", planDescription: "Tickets 123/124",
                emoji: "🛠️")
            let screen = Plan(
                title: "Hiring Screen", planDescription: "30 min", emoji: "🧪")
            let sync = Plan(
                title: "Team Sync", planDescription: "Asks / blockers",
                emoji: "🤝")
            let breakTime = Plan(
                title: "Break", planDescription: "Tea", emoji: "🫖")
            let codeRev = Plan(
                title: "Code Review", planDescription: "Peers' PRs", emoji: "🧯")
            let client = Plan(
                title: "Client Project", planDescription: "Milestone",
                emoji: "🏗️")
            let gym = Plan(
                title: "Gym", planDescription: "Pull day", emoji: "🏋️")
            let groceries = Plan(
                title: "Groceries", planDescription: "Market run", emoji: "🛒")
            let family = Plan(
                title: "Family Time", planDescription: "Play & talk", emoji: "👨‍👩‍👧"
            )
            let cooking = Plan(
                title: "Cooking", planDescription: "Dinner", emoji: "🍲")
            let cleanup = Plan(
                title: "Cleanup", planDescription: "Kitchen", emoji: "🧽")
            let sideProj = Plan(
                title: "Side Project", planDescription: "Prototype", emoji: "🧪")
            let reading = Plan(
                title: "Reading", planDescription: "Novel / docs", emoji: "📚")
            let windDown = Plan(
                title: "Wind Down", planDescription: "Stretch & plan",
                emoji: "🛌")

            // Schedule with **intentional overlaps** across the whole day
            var blocks: [ScheduledPlan] = [
                // 06:00–06:45 Morning routine
                ScheduledPlan(
                    plan: morning, startTime: at(6, 0), duration: mins(45)),
                // 06:30–07:30 Breakfast (overlaps morning 06:30–06:45)
                ScheduledPlan(
                    plan: breakfast, startTime: at(6, 30), duration: mins(60)),
                // 06:50–07:40 Podcast (overlaps breakfast 06:50–07:30)
                ScheduledPlan(
                    plan: podcast, startTime: at(6, 50), duration: mins(50)),

                // 08:00–09:30 Commute
                ScheduledPlan(
                    plan: commute, startTime: at(8, 0), duration: mins(90)),
                // 08:15–08:45 Emails (overlaps commute)
                ScheduledPlan(
                    plan: emails, startTime: at(8, 15), duration: mins(30)),

                // 09:00–10:00 Standup
                ScheduledPlan(
                    plan: standup, startTime: at(9, 0), duration: mins(60)),
                // 09:30–10:15 1:1 (overlaps standup)
                ScheduledPlan(
                    plan: oneOnOne, startTime: at(9, 30), duration: mins(45)),

                // 10:00–12:00 Deep work
                ScheduledPlan(
                    plan: deep, startTime: at(10, 0), duration: mins(120)),
                // 10:30–11:15 PR Review (overlaps deep)
                ScheduledPlan(
                    plan: prReview, startTime: at(10, 30), duration: mins(45)),
                // 11:00–11:45 Design review (overlaps deep)
                ScheduledPlan(
                    plan: designRev, startTime: at(11, 0), duration: mins(45)),

                // 12:00–13:00 Lunch
                ScheduledPlan(
                    plan: lunch, startTime: at(12, 0), duration: mins(60)),
                // 12:15–12:45 Walk (overlaps lunch)
                ScheduledPlan(
                    plan: walk, startTime: at(12, 15), duration: mins(30)),

                // 13:00–15:30 Feature build
                ScheduledPlan(
                    plan: feature, startTime: at(13, 0), duration: mins(150)),
                // 13:30–14:00 Hiring screen (overlaps feature)
                ScheduledPlan(
                    plan: screen, startTime: at(13, 30), duration: mins(30)),
                // 14:30–15:00 Team sync (overlaps feature)
                ScheduledPlan(
                    plan: sync, startTime: at(14, 30), duration: mins(30)),

                // 15:30–16:00 Break
                ScheduledPlan(
                    plan: breakTime, startTime: at(15, 30), duration: mins(30)),
                // 15:45–16:30 Code review (overlaps break 15:45–16:00)
                ScheduledPlan(
                    plan: codeRev, startTime: at(15, 45), duration: mins(45)),

                // 16:00–18:00 Client work
                ScheduledPlan(
                    plan: client, startTime: at(16, 0), duration: mins(120)),

                // 18:00–19:00 Gym
                ScheduledPlan(
                    plan: gym, startTime: at(18, 0), duration: mins(60)),
                // 18:30–19:15 Groceries (overlaps gym)
                ScheduledPlan(
                    plan: groceries, startTime: at(18, 30), duration: mins(45)),

                // 19:00–21:00 Family time
                ScheduledPlan(
                    plan: family, startTime: at(19, 0), duration: mins(120)),
                // 19:30–20:00 Cooking (overlaps family)
                ScheduledPlan(
                    plan: cooking, startTime: at(19, 30), duration: mins(30)),
                // 20:30–21:00 Cleanup (overlaps family)
                ScheduledPlan(
                    plan: cleanup, startTime: at(20, 30), duration: mins(30)),

                // 21:00–22:30 Side project
                ScheduledPlan(
                    plan: sideProj, startTime: at(21, 0), duration: mins(90)),
                // 21:15–21:45 Reading (overlaps side project)
                ScheduledPlan(
                    plan: reading, startTime: at(21, 15), duration: mins(30)),

                // 22:30–23:00 Wind down
                ScheduledPlan(
                    plan: windDown, startTime: at(22, 30), duration: mins(30)),
            ]

            // Optionally mark a dynamic "current" block starting ~10m ago for realism
            let current = ScheduledPlan(
                plan: sync,
                startTime: cal.date(byAdding: .minute, value: -10, to: now)!,
                duration: mins(50))
            blocks.append(current)

            // Persist
            let tpl = DayTemplate(
                name: "Overlap Day (Full)", startTime: startOfDay)
            tpl.scheduledPlans = blocks

            // Assign to today (Monday-based mapping like before)
            let wdApple = cal.component(.weekday, from: now)
            let mondayBased = ((wdApple + 5) % 7) + 1
            let weekday = Weekday(rawValue: mondayBased) ?? .monday
            let assignment = WeekdayAssignment(weekday: weekday, template: tpl)

            // Insert all
            [
                morning, breakfast, podcast, commute, emails, standup, oneOnOne,
                deep, prReview, designRev,
                lunch, walk, feature, screen, sync, breakTime, codeRev, client,
                gym, groceries,
                family, cooking, cleanup, sideProj, reading, windDown,
            ].forEach { ctx.insert($0) }
            blocks.forEach { ctx.insert($0) }
            ctx.insert(tpl)
            ctx.insert(assignment)
            try? ctx.save()
        }
    }
#endif
