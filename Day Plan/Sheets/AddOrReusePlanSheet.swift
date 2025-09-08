//
//  AddOrReusePlanSheet.swift
//  Day Plan
//
//  Restores per-plan Start time input (anchored to caller's day).
//

import SwiftData
import SwiftUI

// Small helper so the chosen time-of-day is placed on the anchor day.
private func anchoredTime(_ time: Date, to anchor: Date) -> Date {
    let cal = Calendar.current
    let t = cal.dateComponents([.hour, .minute, .second], from: time)
    return cal.date(
        bySettingHour: t.hour ?? 0,
        minute: t.minute ?? 0,
        second: t.second ?? 0,
        of: anchor) ?? anchor
}

extension Color {
    static var placeholderText: Color { Color(uiColor: .placeholderText) }
}

struct AddOrReusePlanSheet: View {
    enum Mode: String, CaseIterable {
        case create = "Create New"
        case reuse = "Reuse Existing"
    }

    // NEW: the day to anchor the time-of-day to
    let anchorDay: Date

    // Callback now returns plan + start + length (per-plan start time)
    let onAdd: (_ plan: Plan, _ start: Date, _ lengthMinutes: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var planPendingDeletion: Plan?
    private var isShowingDeleteConfirm: Binding<Bool> {
        Binding(
            get: { planPendingDeletion != nil },
            set: { if !$0 { planPendingDeletion = nil } }
        )
    }

    // UI mode
    @State private var mode: Mode = .create

    // Schedule inputs (both are user-editable)
    @State private var start: Date
    @State private var lengthMinutes: Int

    // Create-new fields
    @State private var title = ""
    @State private var emoji = ""
    @State private var description = ""
    @State private var chosenColor: Color = .accentColor

    @State private var showEmojiPicker = false

    // Reuse-existing
    @Query(sort: \Plan.title) private var allPlans: [Plan]
    @State private var selectedPlanId: UUID?

    init(
        anchorDay: Date,
        initialStart: Date? = nil,
        initialLengthMinutes: Int = 30,
        onAdd: @escaping (_ plan: Plan, _ start: Date, _ lengthMinutes: Int) ->
            Void
    ) {
        self.anchorDay = anchorDay
        self.onAdd = onAdd
        _start = State(
            initialValue: anchoredTime(initialStart ?? .now, to: anchorDay))
        _lengthMinutes = State(initialValue: max(5, initialLengthMinutes))
    }

    var body: some View {
        NavigationStack {
            Form {
                modePickerSection
                planSection
                scheduleSection  // Start time + Length here
            }
            .navigationTitle("Add Plan")
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Delete this plan?",
                isPresented: isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { performDelete() }
                Button("Cancel", role: .cancel) { planPendingDeletion = nil }
            } message: {
                Text(
                    "This removes the plan from your reusable list. Existing schedules keep their time slots (the plan reference becomes empty)."
                )
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var modePickerSection: some View {
        Section {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var planSection: some View {
        switch mode {
        case .create: createPlanSection
        case .reuse: reusePlanSection
        }
    }

    @ViewBuilder
    private var createPlanSection: some View {
        Section("Plan") {
            TextField("Title (e.g. Work, Gym, Lunch)", text: $title)

            Button {
                showEmojiPicker.toggle()
            } label: {
                let isPicked = emoji.isExactlyOneEmoji
                HStack {
                    Text(isPicked ? emoji : "Pick an Emoji")
                        .font(.body)
                        .foregroundStyle(
                            isPicked ? Color.primary : .placeholderText)
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
            ColorPicker(
                "Color", selection: $chosenColor, supportsOpacity: false)
        }

    }

    @ViewBuilder
    private var reusePlanSection: some View {
        Section("Pick a reusable plan") {
            if allPlans.isEmpty {
                ContentUnavailableView(
                    "No saved plans yet", systemImage: "shippingbox")
            } else {
                ForEach(allPlans, id: \.id) { plan in
                    Button {
                        selectedPlanId = plan.id
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(plan.tintColor).frame(
                                width: 10, height: 10)
                            Text("\(plan.emoji) \(plan.title)")
                            Spacer()
                            if selectedPlanId == plan.id {
                                Image(systemName: "checkmark").foregroundStyle(
                                    .primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            planPendingDeletion = plan
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        Section("Schedule") {
            DatePicker(
                "Start", selection: $start, displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            LengthPicker(
                "Length", minutes: $lengthMinutes,
                initialMinutes: max(5, lengthMinutes))
        }
        .onChange(of: start) { newValue in
            // keep time-of-day but re-anchor to the provided day (defensive)
            start = anchoredTime(newValue, to: anchorDay)
        }
    }

    // MARK: - Toolbar & Actions

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Add") { performAdd() }.disabled(!canAdd)
        }
    }

    private func performAdd() {
        // Treat accent as "no custom color" -> store empty string
        func storedHex(for color: Color) -> String {
            let picked = color.toHexRGB()?.uppercased()
            let accent = Color.accentColor.toHexRGB()?.uppercased()
            if let p = picked, let a = accent, p == a { return "" }
            return picked ?? ""
        }

        let plan: Plan
        switch mode {
        case .create:
            let p = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                planDescription: {
                    let trimmed = description.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }(),
                emoji: emoji,
                colorHex: storedHex(for: chosenColor)
            )
            modelContext.insert(p)
            try? modelContext.save()
            plan = p

        case .reuse:
            guard let id = selectedPlanId,
                let found = allPlans.first(where: { $0.id == id })
            else { return }
            plan = found
        }

        onAdd(plan, anchoredTime(start, to: anchorDay), lengthMinutes)
        dismiss()
    }

    private func performDelete() {
        guard let doomed = planPendingDeletion else { return }
        if selectedPlanId == doomed.id { selectedPlanId = nil }
        modelContext.delete(doomed)
        try? modelContext.save()
        planPendingDeletion = nil
    }

    // MARK: - Derived

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
