// ContentView.swift

import Foundation
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayTemplate.name) private var dayTemplates: [DayTemplate]

    @State private var isAddingTemplate = false
    @State private var showWeekSchedule = false  // ✅ NEW

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(dayTemplates) { template in
                    NavigationLink {
                        DayTemplateDetailView(template: template)
                    } label: {
                        Text(template.name)
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
            .navigationTitle("Day Templates")
            .toolbar {
                // ✅ Open Week Schedule as a sheet (works regardless of nav state)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showWeekSchedule = true
                    } label: {
                        Label(
                            "Week Schedule", systemImage: "calendar.badge.clock"
                        )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                ToolbarItem {
                    Button {
                        isAddingTemplate.toggle()
                    } label: {
                        Label("Add Template", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingTemplate) {
                AddDayTemplateView(showWeekScheduleFromHere: $showWeekSchedule)  // ✅ pass binding
            }
            .sheet(isPresented: $showWeekSchedule) {
                WeekScheduleView()
            }
        } detail: {
            Text("Select a Day Template")
        }
    }

    private func deleteTemplates(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(dayTemplates[index])
            }
            try? modelContext.save()  // ✅ ensure relationship nullification is committed
        }
    }
}
