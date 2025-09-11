import Foundation
import SwiftData
import SwiftUI

/// App home: shows today's timeline and links to week schedule & template manager.
/// Kept intentionally lean; all heavy lifting lives in feature screens/VMs.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [WeekdayAssignment]  // for today’s template mapping

    var body: some View {
        NavigationStack {
            List {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        WeekScheduleView()
                    } label: {
                        Label(
                            "Week Schedule", systemImage: "calendar.badge.clock"
                        )
                    }
                }
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
        // Apple: Sunday=1...Saturday=7 -> Monday=1...Sunday=7
        let wd = Calendar.current.component(.weekday, from: Date())
        let mondayBased = ((wd + 5) % 7) + 1
        return Weekday(rawValue: mondayBased) ?? .monday
    }

    private var todaysTemplate: DayTemplate? {
        assignments.first(where: { $0.weekdayRaw == today.rawValue })?.template
    }
}
