import Foundation
import SwiftData
import SwiftUI

// MARK: - Helpers (scoped to this file)

/// Returns `time` placed on the same calendar day as `anchor` (keeps H/M/S).
private func anchoredTime(_ time: Date, to anchor: Date) -> Date {
    let cal = Calendar.current
    let t = cal.dateComponents([.hour, .minute, .second], from: time)
    return cal.date(
        bySettingHour: t.hour ?? 0,
        minute: t.minute ?? 0,
        second: t.second ?? 0,
        of: anchor
    ) ?? anchor
}

/// Clamp so that [start, start + minutes] lies within [anchor, anchor + 24h).
private func clampWithinDay(start: Date, requestedMinutes: Int, anchor: Date)
    -> Int
{
    let endOfDay = anchor.addingTimeInterval(24 * 60 * 60)
    let maxSeconds = max(0, endOfDay.timeIntervalSince(start))
    return max(0, min(requestedMinutes, Int(maxSeconds / 60)))
}

extension Array where Element == ScheduledPlan {
    /// Sorted by start time for stable display.
    var sortedByStart: [ScheduledPlan] {
        self.sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - View

struct DayTemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext

    // Bindable so edits to name / scheduledPlans live-update.
    @Bindable var template: DayTemplate

    @State private var showAddSheet = false

    // The effective anchor for the day (earliest plan or fallback from model).
    private var dayStart: Date { template.dayStart }

    var body: some View {
        List {
            // MARK: Header
            Section {
                TextField("Template name", text: $template.name)
            } footer: {
                Text(
                    "The day’s start is derived automatically from the earliest plan."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            // MARK: Plans
            Section("Plans") {
                if template.scheduledPlans.isEmpty {
                    ContentUnavailableView(
                        "No plans yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text(
                            "Add a plan to start building this day.")
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(template.scheduledPlans.sortedByStart) { sp in
                        planRow(sp)
                    }
                    .onDelete(perform: deleteScheduledPlans)
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Plan", systemImage: "plus")
                }
            }
        }
        .navigationTitle(template.name.isEmpty ? "Day Template" : template.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddOrReusePlanSheet(
                anchorDay: dayStart,
                initialStart: anchoredTime(.now, to: dayStart),
                initialLengthMinutes: 60
            ) { plan, start, length in
                let anchoredStart = anchoredTime(start, to: dayStart)
                let minutes = clampWithinDay(
                    start: anchoredStart,
                    requestedMinutes: length,
                    anchor: dayStart
                )

                let scheduled = ScheduledPlan(
                    plan: plan,
                    startTime: anchoredStart,
                    duration: TimeInterval(minutes * 60)
                )
                scheduled.dayTemplate = template
                modelContext.insert(scheduled)
                try? modelContext.save()
            }
        }

    }

    // MARK: - Rows

    @ViewBuilder
    private func planRow(_ sp: ScheduledPlan) -> some View {
        // Live bindings so DatePicker / LengthPicker update SwiftData.
        let startBinding = Binding<Date>(
            get: { sp.startTime },
            set: { newValue in
                // Keep the chosen time but place it on the anchor day.
                let anchored = anchoredTime(newValue, to: dayStart)
                sp.startTime = anchored
                // Re-clamp its duration in case the new start is near the end of day.
                let minutes = clampWithinDay(
                    start: anchored,
                    requestedMinutes: Int(sp.duration / 60),
                    anchor: dayStart
                )
                sp.duration = TimeInterval(minutes * 60)
                try? modelContext.save()
            }
        )

        let minutesBinding = Binding<Int>(
            get: { max(0, Int(sp.duration / 60)) },
            set: { newLen in
                // Clamp relative to the anchor day/window.
                let anchored = anchoredTime(sp.startTime, to: dayStart)
                let minutes = clampWithinDay(
                    start: anchored,
                    requestedMinutes: newLen,
                    anchor: dayStart
                )
                sp.startTime = anchored
                sp.duration = TimeInterval(minutes * 60)
                try? modelContext.save()
            }
        )

        HStack(alignment: .top, spacing: 12) {
            Text(
                sp.plan?.emoji.isEmpty == false ? (sp.plan?.emoji ?? "🧩") : "🧩"
            )
            .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(sp.plan?.title ?? "Untitled")
                        .font(.headline)
                    if sp.plan == nil {
                        Text("Deleted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(rowSubtitle(for: sp))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Editors
                DatePicker(
                    "Start",
                    selection: startBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)

                LengthPicker(
                    "Length",
                    minutes: minutesBinding,
                    initialMinutes: max(5, minutesBinding.wrappedValue)
                )
            }
        }
    }

    // MARK: - Actions

    private func deleteScheduledPlans(at offsets: IndexSet) {
        let sorted = template.scheduledPlans.sortedByStart
        for idx in offsets {
            let sp = sorted[idx]
            modelContext.delete(sp)
        }
        try? modelContext.save()
    }

    // MARK: - Formatting

    private func rowSubtitle(for sp: ScheduledPlan) -> String {
        let start = sp.startTime
        let end = sp.startTime.addingTimeInterval(sp.duration)
        let mins = Int(sp.duration / 60)
        return
            "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(mins))"
    }
}
