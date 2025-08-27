import SwiftData
import SwiftUI

struct DayTemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: DayTemplate
    @State private var showingAdd = false
    @State private var editing: ScheduledPlan?

    private func delete(at offsets: IndexSet) {
        let items = sortedPlans
        for index in offsets { modelContext.delete(items[index]) }
        try? modelContext.save()
    }

    var body: some View {
        Form {
            Section("Template") {
                TextField("Name", text: $template.name)
                DatePicker(
                    "Start time", selection: $template.startTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .onChange(of: template.startTime) { _ in
                    reflowForNewDayStart()
                    try? modelContext.save()
                }
            }

            Section {
                if sortedPlans.isEmpty {
                    ContentUnavailableView(
                        "No plans yet", systemImage: "list.bullet.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(sortedPlans) { sp in
                        Button {
                            editing = sp
                        } label: {
                            PlanRowView(
                                emoji: sp.plan?.emoji ?? "🧩",
                                title: sp.plan?.title ?? "Untitled",
                                description: sp.plan?.planDescription,
                                start: sp.startTime,
                                durationSeconds: sp.duration
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(sp)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            } header: {
                HStack {
                    Text("Plans")
                    Spacer()
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) {
            AddOrReusePlanSheet(
                dayStart: template.startTime,
                earliestStart: earliestAvailableStart(),
                remainingMinutes: remainingMinutesToday()
            ) { plan, start, lengthMinutes in
                let startClamped = max(
                    TimeUtil.anchoredTime(start, to: template.startTime),
                    earliestAvailableStart())
                let minutes = DayScheduleEngine.clampDurationWithinDay(
                    start: startClamped,
                    requestedMinutes: lengthMinutes,
                    day: DayWindow(start: template.startTime))
                let sp = ScheduledPlan(
                    plan: plan, startTime: startClamped,
                    duration: TimeInterval(minutes * 60))
                sp.dayTemplate = template
                try? modelContext.save()
            }
        }
        .sheet(item: $editing) { sp in
            EditScheduledPlanSheet(
                template: template,
                planToEdit: sp,
                onSaved: { try? modelContext.save() },
                onDelete: {
                    modelContext.delete(sp)
                    try? modelContext.save()
                }
            )
        }
        .onDisappear { try? modelContext.save() }
    }

    // Helpers via SchedulingKit
    private var sortedPlans: [ScheduledPlan] {
        (template.scheduledPlans ?? []).sorted { $0.startTime < $1.startTime }
    }
    private func earliestAvailableStart() -> Date {
        DayScheduleEngine.earliestAvailableStart(
            day: DayWindow(start: template.startTime), items: sortedPlans,
            getStart: { $0.startTime }, getDuration: { $0.duration })
    }
    private func remainingMinutesToday() -> Int {
        DayScheduleEngine.remainingMinutes(
            day: DayWindow(start: template.startTime), items: sortedPlans,
            getStart: { $0.startTime }, getDuration: { $0.duration })
    }
    private func reflowForNewDayStart() {
        _ = DayScheduleEngine.reflow(
            day: DayWindow(start: template.startTime), items: sortedPlans,
            getStart: { $0.startTime }, getDuration: { $0.duration },
            setStart: { $0.startTime = $1 }, setDuration: { $0.duration = $1 })
    }
}
