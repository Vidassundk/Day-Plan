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
            initialValue: max(5, Int(planToEdit.duration / 60))
        )
    }

    var body: some View {
        // 24h window anchored at the Whole schedule start (template.startTime)
        let day = DayWindow(start: template.dayStart)

        NavigationStack {
            Form {
                // MARK: Plan
                Section("Plan") {
                    Picker("Reusable plan", selection: $selectedPlanId) {
                        ForEach(allPlans) { p in
                            Text("\(p.emoji) \(p.title)").tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // MARK: Schedule
                Section("Schedule") {
                    // NOTE: Removed the "Allowed window" readout entirely.

                    DatePicker(
                        "Start",
                        selection: $start,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: start) { newValue in
                        let anchored = TimeUtil.anchoredTime(
                            newValue, to: template.dayStart)
                        start = anchored
                        lengthMinutes =
                            DayScheduleEngine.clampDurationWithinDay(
                                start: anchored,
                                requestedMinutes: lengthMinutes,
                                day: day
                            )
                    }

                    LengthPicker(
                        "Length",
                        minutes: $lengthMinutes,
                        initialMinutes: max(5, lengthMinutes)
                    )
                    .onChange(of: lengthMinutes) { mins in
                        let anchoredStart = TimeUtil.anchoredTime(
                            start, to: template.dayStart)
                        lengthMinutes =
                            DayScheduleEngine.clampDurationWithinDay(
                                start: anchoredStart,
                                requestedMinutes: mins,
                                day: day
                            )
                    }

                    // Preview the effective run
                    let anchoredStart = TimeUtil.anchoredTime(
                        start, to: template.startTime)
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

                        let startAnchored = TimeUtil.anchoredTime(
                            start, to: template.dayStart)
                        planToEdit.startTime = startAnchored

                        let clamped = DayScheduleEngine.clampDurationWithinDay(
                            start: startAnchored,
                            requestedMinutes: max(5, lengthMinutes),
                            day: day
                        )
                        planToEdit.duration = TimeInterval(clamped * 60)

                        onSaved()
                        dismiss()
                    }
                    // No more prev/next window rule; only disable if you want to force choosing a plan.
                    //.disabled(selectedPlanId == nil)
                }
            }
        }
    }
}
