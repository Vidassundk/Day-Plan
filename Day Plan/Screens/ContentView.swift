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
            // In-memory container for previews
            let schema = Schema([
                DayTemplate.self,
                ScheduledPlan.self,
                Plan.self,
                WeekdayAssignment.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(
                for: schema, configurations: config)

            seedDemoData(into: container)  // <- non-overlapping schedule

            return ContentView()
                .modelContainer(container)
                .previewDisplayName(
                    "ContentView — Timeline Only (Push Links)")
        }

        /// Seeds a realistic Workday timeline with past / current / upcoming items,
        /// ensuring NO overlaps and a small gap between events.
        private static func seedDemoData(into container: ModelContainer) {
            let ctx = container.mainContext
            let cal = Calendar.current
            let now = Date()
            let startOfDay = cal.startOfDay(for: now)

            // --- Domain plans (sample data)
            let standup = Plan(
                title: "Standup", planDescription: "Sprint 42", emoji: "👥")
            let design = Plan(
                title: "Design Review", planDescription: "UI polish", emoji: "🎨"
            )
            let code = Plan(
                title: "Deep Work", planDescription: "Feature branch",
                emoji: "💻")
            let lunch = Plan(
                title: "Lunch", planDescription: "Chicken salad", emoji: "🥗")
            let sync = Plan(
                title: "Client Sync", planDescription: "Weekly check-in",
                emoji: "🤝")
            let read = Plan(
                title: "Reading", planDescription: "Docs & notes", emoji: "📚")
            let gym = Plan(
                title: "Workout", planDescription: "Push day", emoji: "💪")

            // --- Anchors we "prefer" to use; we’ll clamp them to avoid overlaps
            let at0900 = cal.date(byAdding: .hour, value: 9, to: startOfDay)!  // 09:00
            let at0950 = at0900.addingTimeInterval(50 * 60)  // 09:50
            let at1300 = cal.date(byAdding: .hour, value: 13, to: startOfDay)!  // 13:00
            let at1400 = cal.date(byAdding: .hour, value: 14, to: startOfDay)!  // 14:00
            let at1500 = cal.date(byAdding: .hour, value: 15, to: startOfDay)!  // 15:00
            let at1700 = cal.date(byAdding: .hour, value: 17, to: startOfDay)!  // 17:00
            let at1800 = cal.date(byAdding: .hour, value: 18, to: startOfDay)!  // 18:00

            // --- Durations
            let d0: TimeInterval = 30 * 60
            let d1: TimeInterval = 40 * 60
            let d2: TimeInterval = 60 * 60  // current
            let d3: TimeInterval = 45 * 60
            let d4: TimeInterval = 45 * 60
            let d5: TimeInterval = 90 * 60
            let d6: TimeInterval = 30 * 60
            let d7: TimeInterval = 45 * 60

            // --- We want the "current" block to have started ~15m ago (but never overlap previous)
            let proposedCurrentStart =
                cal.date(byAdding: .minute, value: -15, to: now) ?? now

            // --- Non-overlap placement with a minimum gap
            let gapMinutes = 10
            let gap: TimeInterval = TimeInterval(gapMinutes * 60)
            var lastEnd: Date?

            func place(_ proposed: Date, duration: TimeInterval) -> Date {
                let earliest = (lastEnd?.addingTimeInterval(gap)) ?? proposed
                let start = max(proposed, earliest)
                lastEnd = start.addingTimeInterval(duration)
                return start
            }

            // Place items in order; each start is clamped by (lastEnd + gap)
            let s0 = place(at0900, duration: d0)
            let s1 = place(at0950, duration: d1)
            let s2 = place(
                max(proposedCurrentStart, lastEnd ?? proposedCurrentStart),
                duration: d2)  // current
            let s3 = place(at1300, duration: d3)
            let s4 = place(at1400, duration: d4)
            let s5 = place(at1500, duration: d5)
            let s6 = place(at1700, duration: d6)
            let s7 = place(at1800, duration: d7)

            // --- Build ScheduledPlans with the actual (non-overlapping) starts
            let sp0 = ScheduledPlan(plan: standup, startTime: s0, duration: d0)
            let sp1 = ScheduledPlan(plan: design, startTime: s1, duration: d1)
            let sp2 = ScheduledPlan(plan: code, startTime: s2, duration: d2)  // current
            let sp3 = ScheduledPlan(plan: lunch, startTime: s3, duration: d3)
            let sp4 = ScheduledPlan(plan: sync, startTime: s4, duration: d4)
            let sp5 = ScheduledPlan(plan: code, startTime: s5, duration: d5)
            let sp6 = ScheduledPlan(plan: read, startTime: s6, duration: d6)
            let sp7 = ScheduledPlan(plan: gym, startTime: s7, duration: d7)

            // --- Template + assignment for *today*
            let workday = DayTemplate(name: "Workday", startTime: startOfDay)
            workday.scheduledPlans = [sp0, sp1, sp2, sp3, sp4, sp5, sp6, sp7]

            // Map Apple weekday (Sun=1..Sat=7) to your Monday-based enum (Mon=1..Sun=7)
            let wdApple = cal.component(.weekday, from: now)
            let mondayBased = ((wdApple + 5) % 7) + 1
            let weekday = Weekday(rawValue: mondayBased) ?? .monday
            let assignment = WeekdayAssignment(
                weekday: weekday, template: workday)

            // --- Persist (typed inserts to avoid inference issues)
            [standup, design, code, lunch, sync, read, gym].forEach {
                ctx.insert($0)
            }
            [sp0, sp1, sp2, sp3, sp4, sp5, sp6, sp7].forEach { ctx.insert($0) }
            ctx.insert(workday)
            ctx.insert(assignment)
            try? ctx.save()
        }
    }
#endif
