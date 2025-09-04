//
//  AddOrReusePlanSheet.swift
//  Day Plan
//
//  Created by Vidas Sun on 27/08/2025.
//

import SwiftData
import SwiftUI

extension Color {
    static var placeholderText: Color { Color(uiColor: .placeholderText) }
}

struct AddOrReusePlanSheet: View {
    enum Mode: String, CaseIterable {
        case create = "Create New"
        case reuse = "Reuse Existing"
    }

    // ⬇️ Simplified inputs
    let anchorDay: Date
    let onAdd: (_ plan: Plan, _ start: Date, _ lengthMinutes: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 1) state to show a popover picker
    @State private var showEmojiPicker = false

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
        anchorDay: Date,
        onAdd: @escaping (_ plan: Plan, _ start: Date, _ lengthMinutes: Int) ->
            Void
    ) {
        self.anchorDay = anchorDay
        self.onAdd = onAdd
        _start = State(initialValue: anchorDay)  // HH:mm editor needs a stable date
        _lengthMinutes = State(initialValue: 30)  // default; still min 5 via LengthPicker
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                    }.pickerStyle(.segmented)
                }

                if mode == .create {
                    Section("Plan") {
                        TextField("Title (e.g. Work, Gym, Lunch)", text: $title)

                        Button {
                            showEmojiPicker.toggle()
                        } label: {
                            let isPicked = emoji.isExactlyOneEmoji
                            HStack {
                                Text(isPicked ? emoji : "Pick an Emoji")
                                    .font(.body)
                                    // Use Color on BOTH sides so the types match
                                    .foregroundStyle(
                                        isPicked
                                            ? Color.primary
                                            : Color(uiColor: .placeholderText)
                                    )
                                // (optional) make the picked emoji a bit larger:
                                //.font(isPicked ? .title3 : .body)

                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .popover(
                            isPresented: $showEmojiPicker,
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .trailing
                        ) {
                            EmojiKitPickerView(selection: $emoji)
                                .presentationCompactAdaptation(.sheet)
                        }

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
                    // ⛔️ REMOVE the “Earliest available” & “Remaining today” rows.
                    // (These implied blocking logic.)

                    DatePicker(
                        "Start", selection: $start,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    // ⛔️ REMOVE clamping in onChange — overlaps and out-of-order are allowed now.

                    LengthPicker(
                        "Length", minutes: $lengthMinutes, initialMinutes: 30)
                    // ⛔️ No disabling based on remaining time.

                    let anchoredStart = TimeUtil.anchoredTime(
                        start, to: anchorDay)
                    let end = anchoredStart.addingTimeInterval(
                        TimeInterval(lengthMinutes * 60))
                    LabeledContent("Will run") {
                        Text(
                            "\(anchoredStart.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) (\(TimeUtil.formatMinutes(lengthMinutes)))"
                        )
                        .foregroundStyle(.secondary)
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
                        // ✅ No length/start clamps. Just anchor HH:mm to a stable date for storage.
                        let anchoredStart = TimeUtil.anchoredTime(
                            start, to: anchorDay)

                        let plan: Plan
                        switch mode {
                        case .create:
                            let p = Plan(
                                title: title.trimmingCharacters(
                                    in: .whitespacesAndNewlines),
                                planDescription: description.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty ? nil : description,
                                emoji: emoji  // guaranteed one emoji now
                            )
                            modelContext.insert(p)
                            try? modelContext.save()  // persist for reuse
                            plan = p
                        case .reuse:
                            plan = allPlans.first { $0.id == selectedPlanId! }!
                        }

                        onAdd(plan, anchoredStart, lengthMinutes)
                        dismiss()
                    }
                    .disabled(!canAdd)  // only gate on having a plan/title selected
                }
            }
        }
    }

    private var canAdd: Bool {
        switch mode {
        case .create:
            let hasTitle = !title.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
            return hasTitle && emoji.isExactlyOneEmoji
        case .reuse:
            return selectedPlanId != nil
        }
    }

}
