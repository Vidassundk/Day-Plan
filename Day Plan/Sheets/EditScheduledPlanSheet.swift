//
//  EditScheduledPlanSheet.swift
//  Day Plan
//
//  Created by Vidas Sun on 27/08/2025.
//

import SwiftData
import SwiftUI

struct EditScheduledPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var template: DayTemplate
    let planToEdit: ScheduledPlan
    let onSaved: () -> Void
    let onDelete: () -> Void

    @Query(sort: \Plan.title) private var allPlans: [Plan]

    @State private var selectedPlanId: UUID?
    @State private var start: Date
    @State private var lengthMinutes: Int

    init(
        template: DayTemplate, planToEdit: ScheduledPlan,
        onSaved: @escaping () -> Void, onDelete: @escaping () -> Void
    ) {
        self.template = template
        self.planToEdit = planToEdit
        self.onSaved = onSaved
        self.onDelete = onDelete

        _selectedPlanId = State(initialValue: planToEdit.plan?.id)
        _start = State(initialValue: planToEdit.startTime)
        _lengthMinutes = State(
            initialValue: max(5, Int(planToEdit.duration / 60)))
    }

    var body: some View {
        let sorted = (template.scheduledPlans ?? []).sorted {
            $0.startTime < $1.startTime
        }
        let idx = sorted.firstIndex(where: { $0.id == planToEdit.id }) ?? 0

        let prevEnd =
            idx == 0
            ? template.startTime
            : sorted[idx - 1].startTime.addingTimeInterval(
                sorted[idx - 1].duration)

        let dayEnd = template.startTime.addingTimeInterval(24 * 60 * 60)
        let nextStart =
            idx + 1 < sorted.count ? sorted[idx + 1].startTime : dayEnd

        NavigationStack {
            Form {
                Section("Plan") {
                    Picker("Reusable plan", selection: $selectedPlanId) {
                        ForEach(allPlans) { p in
                            Text("\(p.emoji) \(p.title)").tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Schedule") {
                    LabeledContent("Allowed window") {
                        Text(
                            "\(prevEnd.formatted(date: .omitted, time: .shortened)) – \(nextStart.formatted(date: .omitted, time: .shortened))"
                        )
                        .foregroundStyle(.secondary)
                    }

                    DatePicker(
                        "Start", selection: $start,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: start) { value in
                        let anchored = TimeUtil.anchoredTime(
                            value, to: template.startTime)
                        if anchored < prevEnd { start = prevEnd }
                        if anchored > nextStart { start = nextStart }
                    }

                    LengthPicker(
                        "Length", minutes: $lengthMinutes,
                        initialMinutes: max(5, lengthMinutes)
                    )
                    .onChange(of: lengthMinutes) { mins in
                        // Ensure length fits in window; if not, clamp it
                        let anchoredStart = max(
                            TimeUtil.anchoredTime(
                                start, to: template.startTime), prevEnd)
                        let maxAllowed = Int(
                            nextStart.timeIntervalSince(anchoredStart) / 60)
                        if mins > maxAllowed {
                            lengthMinutes = max(0, maxAllowed)
                        }
                    }

                    let anchoredStart = max(
                        TimeUtil.anchoredTime(start, to: template.startTime),
                        prevEnd)
                    let end = anchoredStart.addingTimeInterval(
                        TimeInterval(lengthMinutes * 60))
                    LabeledContent("Will run") {
                        Text(
                            "\(anchoredStart.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) (\(TimeUtil.formatMinutes(lengthMinutes)))"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Plan", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let p = allPlans.first(where: {
                            $0.id == selectedPlanId
                        }) {
                            planToEdit.plan = p
                        }
                        let startClamped = max(
                            TimeUtil.anchoredTime(
                                start, to: template.startTime), prevEnd)
                        planToEdit.startTime = startClamped

                        let maxAllowed = nextStart.timeIntervalSince(
                            startClamped)
                        planToEdit.duration = min(
                            maxAllowed, TimeInterval(max(5, lengthMinutes) * 60)
                        )

                        onSaved()
                        dismiss()
                    }
                    .disabled(selectedPlanId == nil || nextStart <= prevEnd)
                }
            }
        }
    }
}
