// ContentView.swift

import Foundation
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Data
    @Query(sort: \DayTemplate.name) private var dayTemplates: [DayTemplate]
    @Query private var assignments: [WeekdayAssignment]  // for today’s mapping

    // UI state
    @State private var isAddingTemplate = false
    @State private var showWeekSchedule = false

    var body: some View {
        NavigationSplitView {
            List {
                // MARK: Today
                Section(todaySectionTitle) {
                    if let template = todaysTemplate {
                        TodayTimelineView(template: template)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No template assigned for today.")
                                .foregroundStyle(.secondary)
                            Button {
                                showWeekSchedule = true
                            } label: {
                                Label(
                                    "Assign a template",
                                    systemImage: "calendar.badge.clock")
                            }
                        }
                    }
                }

                // MARK: Templates list
                Section("Day Templates") {
                    ForEach(dayTemplates) { template in
                        NavigationLink {
                            DayTemplateDetailView(template: template)
                        } label: {
                            Text(template.name)
                        }
                    }
                    .onDelete(perform: deleteTemplates)
                }
            }
            .navigationTitle("Day Planner")
            .toolbar {
                // Week schedule button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showWeekSchedule = true
                    } label: {
                        Label(
                            "Week Schedule", systemImage: "calendar.badge.clock"
                        )
                    }
                }
                // Edit / Add
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                ToolbarItem {
                    Button {
                        isAddingTemplate.toggle()
                    } label: {
                        Label("Add Template", systemImage: "plus")
                    }
                }
            }
            // Sheets
            .sheet(isPresented: $isAddingTemplate) {
                AddDayTemplateView(showWeekScheduleFromHere: $showWeekSchedule)
            }
            .sheet(isPresented: $showWeekSchedule) {
                WeekScheduleView()
            }
        } detail: {
            Text("Select a Day Template")
        }
    }

    // MARK: - Today helpers

    private var today: Weekday {
        // Map Apple’s Sunday=1...Saturday=7 to our Monday=1...Sunday=7
        let wd = Calendar.current.component(.weekday, from: Date())  // 1...7 (Sun=1)
        let mondayBased = ((wd + 5) % 7) + 1  // Mon=1 ... Sun=7
        return Weekday(rawValue: mondayBased) ?? .monday
    }

    private var todaySectionTitle: String {
        "Today — \(today.name)"
    }

    private var todaysTemplate: DayTemplate? {
        assignments.first(where: { $0.weekdayRaw == today.rawValue })?.template
    }

    private func currentOrNextPlan(for template: DayTemplate)
        -> (current: ScheduledPlan?, next: ScheduledPlan?)
    {
        let plans = (template.scheduledPlans ?? []).sorted {
            $0.startTime < $1.startTime
        }
        guard !plans.isEmpty else { return (nil, nil) }

        // Anchor “now” to the same reference day as the template’s schedule
        let nowAnchored = TimeUtil.anchoredTime(Date(), to: template.startTime)

        for sp in plans {
            let start = sp.startTime
            let end = start.addingTimeInterval(sp.duration)
            if nowAnchored < start {
                // Next plan hasn’t started yet
                return (nil, sp)
            } else if nowAnchored >= start && nowAnchored < end {
                // We’re in this plan right now; also compute the next if you want
                // Find next:
                let idx = plans.firstIndex(where: { $0.id == sp.id }) ?? 0
                let next = (idx + 1 < plans.count) ? plans[idx + 1] : nil
                return (sp, next)
            }
        }
        // All plans are in the past
        return (nil, nil)
    }

    // MARK: - Mutations

    private func deleteTemplates(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(dayTemplates[index])
            }
            try? modelContext.save()  // ensure nullify of WeekdayAssignment.template
        }
    }
}
