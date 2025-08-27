//
//  AddOrReusePlanSheet.swift
//  Day Plan
//
//  Created by Vidas Sun on 27/08/2025.
//

import SwiftData
import SwiftUI

struct AddOrReusePlanSheet: View {
    enum Mode: String, CaseIterable {
        case create = "Create New"
        case reuse = "Reuse Existing"
    }

    let dayStart: Date
    let earliestStart: Date  // computed by parent
    let remainingMinutes: Int  // minutes left in the 24h window
    let onAdd: (_ plan: Plan, _ start: Date, _ lengthMinutes: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var mode: Mode = .create
    @State private var start: Date
    @State private var lengthMinutes: Int

    // Create-new fields
    @State private var title = ""
    @State private var emoji = ""
    @State private var description = ""

    // Reuse-existing
    @Query(sort: \Plan.title) private var allPlans: [Plan]
    @State private var selectedPlanId: UUID?

    init(
        dayStart: Date, earliestStart: Date, remainingMinutes: Int,
        onAdd: @escaping (_ plan: Plan, _ start: Date, _ lengthMinutes: Int) ->
            Void
    ) {
        self.dayStart = dayStart
        self.earliestStart = earliestStart
        self.remainingMinutes = remainingMinutes
        self.onAdd = onAdd
        _start = State(initialValue: earliestStart)
        _lengthMinutes = State(initialValue: max(5, min(30, remainingMinutes)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .create {
                    Section("Plan") {
                        TextField("Title (e.g. Work, Gym, Lunch)", text: $title)
                        TextField("Emoji (e.g. 💼, 🏋️, 🍔)", text: $emoji)
                        TextField("Description (optional)", text: $description)
                    }
                } else {
                    Section("Pick a reusable plan") {
                        if allPlans.isEmpty {
                            ContentUnavailableView(
                                "No saved plans yet", systemImage: "shippingbox"
                            )
                        } else {
                            Picker("Plan", selection: $selectedPlanId) {
                                Text("Select…").tag(Optional<UUID>.none)
                                ForEach(allPlans) { p in
                                    Text("\(p.emoji) \(p.title)").tag(
                                        Optional(p.id))
                                }
                            }
                            .pickerStyle(.navigationLink)
                        }
                    }
                }

                Section("Schedule") {
                    LabeledContent("Earliest available") {
                        Text(
                            earliestStart.formatted(
                                date: .omitted, time: .shortened)
                        )
                        .foregroundStyle(.secondary)
                    }
                    LabeledContent("Remaining today") {
                        Text(TimeUtil.formatMinutes(remainingMinutes))
                            .foregroundStyle(
                                remainingMinutes == 0 ? .red : .secondary)
                    }

                    DatePicker(
                        "Start", selection: $start,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: start) { val in
                        let anchored = TimeUtil.anchoredTime(val, to: dayStart)
                        let minAllowed = max(dayStart, earliestStart)
                        if anchored < minAllowed { start = minAllowed }
                    }

                    LengthPicker(
                        "Length", minutes: $lengthMinutes,
                        initialMinutes: max(5, min(30, remainingMinutes))
                    )
                    .disabled(remainingMinutes <= 0)

                    let anchoredStart = TimeUtil.anchoredTime(
                        start, to: dayStart)
                    let end = anchoredStart.addingTimeInterval(
                        TimeInterval(lengthMinutes * 60))
                    LabeledContent("Will run") {
                        Text(
                            "\(anchoredStart.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) (\(TimeUtil.formatMinutes(lengthMinutes)))"
                        )
                        .foregroundStyle(.secondary)
                    }

                    if remainingMinutes <= 0 {
                        Text(
                            "No time left in today's 24-hour cycle from the schedule start."
                        )
                        .font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let clampedStart = max(
                            TimeUtil.anchoredTime(start, to: dayStart),
                            max(dayStart, earliestStart)
                        )
                        let clampedLen =
                            DayScheduleEngine.clampDurationWithinDay(
                                start: clampedStart,
                                requestedMinutes: lengthMinutes,
                                day: DayWindow(start: dayStart)
                            )

                        let plan: Plan
                        switch mode {
                        case .create:
                            let p = Plan(
                                title: title.trimmingCharacters(
                                    in: .whitespacesAndNewlines),
                                planDescription: description.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty ? nil : description,
                                emoji: emoji.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty ? "🧩" : emoji
                            )
                            modelContext.insert(p)
                            try? modelContext.save()  // persist for reuse
                            plan = p
                        case .reuse:
                            plan = allPlans.first { $0.id == selectedPlanId! }!
                        }

                        onAdd(plan, clampedStart, clampedLen)
                        dismiss()
                    }
                    .disabled(!canAdd || remainingMinutes < 5)
                }
            }
        }
    }

    private var canAdd: Bool {
        switch mode {
        case .create:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        case .reuse: return selectedPlanId != nil
        }
    }
}
