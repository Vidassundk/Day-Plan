import SwiftData
import SwiftUI

/// Add a new Day Template with free-form plan times.
/// - No "available time" calculations
/// - No reflowing when start changes
/// - The only constraint: for each draft, `start + length` must be <= dayStart + 24h.
struct AddDayTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var showWeekScheduleFromHere: Bool
    init(showWeekScheduleFromHere: Binding<Bool> = .constant(false)) {
        _showWeekScheduleFromHere = showWeekScheduleFromHere
    }

    @State private var name: String = ""
    /// "Whole schedule start" anchor; the 24h window is [startTime, startTime + 24h)
    @State private var startTime: Date = Calendar.current.startOfDay(for: .now)

    @State private var drafts: [PlanEntryDraft] = []

    @Query(sort: \Plan.title) private var allPlans: [Plan]

    // Add plan sheet state
    @State private var showAddSheet = false
    @State private var addMode: AddPlanMode = .reuse
    @State private var newPlanTitle: String = ""
    @State private var newPlanEmoji: String = "🧩"
    @State private var selectedPlanId: UUID?
    @State private var sheetStart: Date = Calendar.current.startOfDay(for: .now)
    @State private var sheetLength: Int = 60

    var body: some View {
        let day = DayWindow(start: startTime)

        NavigationStack {
            Form {
                // MARK: Template
                Section("Template") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                }

                // MARK: Plans
                Section("Plans") {
                    if drafts.isEmpty {
                        ContentUnavailableView(
                            "No plans yet", systemImage: "list.bullet.rectangle"
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(sortedDrafts()) { draft in
                            draftRow(draft: draft, day: day)
                        }
                        .onDelete(perform: deleteDrafts)
                    }

                    Button {
                        showAddSheet = true
                        addMode = .reuse
                        newPlanTitle = ""
                        newPlanEmoji = "🧩"
                        selectedPlanId = allPlans.first?.id
                        sheetStart = TimeUtil.anchoredTime(.now, to: startTime)
                        sheetLength = 60
                    } label: {
                        Label("Add Plan", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Day Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTemplate() }
                        .disabled(drafts.isEmpty)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addPlanSheet(day: day)
            }
        }
    }

    // MARK: - Rows

    private func draftRow(draft: PlanEntryDraft, day: DayWindow) -> some View {
        // Binding helpers to mutate the specific draft in place
        let idx = drafts.firstIndex(where: { $0.id == draft.id })!

        return HStack(spacing: 12) {
            Text(
                draft.existingPlan.emoji.isEmpty
                    ? "🧩" : draft.existingPlan.emoji
            )
            .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    draft.existingPlan.title.isEmpty
                        ? "Untitled" : draft.existingPlan.title)

                // Timing display (anchored + clamped preview)
                let anchoredStart = TimeUtil.anchoredTime(
                    draft.start, to: day.start)
                let clampedLen = DayScheduleEngine.clampDurationWithinDay(
                    start: anchoredStart,
                    requestedMinutes: drafts[idx].lengthMinutes,
                    day: day
                )
                let end = anchoredStart.addingTimeInterval(
                    TimeInterval(clampedLen * 60))

                Text(
                    "\(anchoredStart.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(clampedLen))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                // Editors
                DatePicker(
                    "Start",
                    selection: Binding(
                        get: { drafts[idx].start },
                        set: { newValue in
                            let anchored = TimeUtil.anchoredTime(
                                newValue, to: day.start)
                            drafts[idx].start = anchored
                            drafts[idx].lengthMinutes =
                                DayScheduleEngine.clampDurationWithinDay(
                                    start: anchored,
                                    requestedMinutes: drafts[idx].lengthMinutes,
                                    day: day
                                )
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)

                LengthPicker(
                    "Length",
                    minutes: Binding(
                        get: { drafts[idx].lengthMinutes },
                        set: { newLen in
                            drafts[idx].lengthMinutes =
                                DayScheduleEngine.clampDurationWithinDay(
                                    start: TimeUtil.anchoredTime(
                                        drafts[idx].start, to: day.start),
                                    requestedMinutes: newLen,
                                    day: day
                                )
                        }
                    ),
                    initialMinutes: max(5, drafts[idx].lengthMinutes)
                )
            }
        }
    }

    // MARK: - Add Plan Sheet

    private func addPlanSheet(day: DayWindow) -> some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $addMode) {
                    Text("Reuse plan").tag(AddPlanMode.reuse)
                    Text("Create new plan").tag(AddPlanMode.new)
                }
                .pickerStyle(.segmented)

                if addMode == .reuse {
                    Section("Pick a plan") {
                        Picker("Reusable plan", selection: $selectedPlanId) {
                            ForEach(allPlans) { p in
                                Text("\(p.emoji) \(p.title)").tag(
                                    Optional(p.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                } else {
                    Section("New plan") {
                        TextField("Title", text: $newPlanTitle)
                        TextField("Emoji", text: $newPlanEmoji)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Timing") {
                    DatePicker(
                        "Start",
                        selection: $sheetStart,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: sheetStart) { newValue in
                        sheetStart = TimeUtil.anchoredTime(
                            newValue, to: day.start)
                        sheetLength = DayScheduleEngine.clampDurationWithinDay(
                            start: sheetStart,
                            requestedMinutes: sheetLength,
                            day: day
                        )
                    }

                    LengthPicker(
                        "Length",
                        minutes: $sheetLength,
                        initialMinutes: max(5, sheetLength)
                    )
                    .onChange(of: sheetLength) { newLen in
                        sheetLength = DayScheduleEngine.clampDurationWithinDay(
                            start: TimeUtil.anchoredTime(
                                sheetStart, to: day.start),
                            requestedMinutes: newLen,
                            day: day
                        )
                    }
                }
            }
            .navigationTitle("Add Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let anchoredStart = TimeUtil.anchoredTime(
                            sheetStart, to: day.start)
                        let clamped = DayScheduleEngine.clampDurationWithinDay(
                            start: anchoredStart,
                            requestedMinutes: sheetLength,
                            day: day
                        )

                        switch addMode {
                        case .reuse:
                            guard let id = selectedPlanId,
                                let plan = allPlans.first(where: { $0.id == id }
                                )
                            else { return }
                            drafts.append(
                                PlanEntryDraft(
                                    existingPlan: plan, start: anchoredStart,
                                    lengthMinutes: clamped
                                ))

                        case .new:
                            let title = newPlanTitle.trimmingCharacters(
                                in: .whitespacesAndNewlines)
                            let plan = Plan(
                                title: title.isEmpty ? "Untitled" : title,
                                planDescription: nil,
                                emoji: newPlanEmoji.isEmpty ? "🧩" : newPlanEmoji
                            )
                            modelContext.insert(plan)
                            try? modelContext.save()
                            drafts.append(
                                PlanEntryDraft(
                                    existingPlan: plan, start: anchoredStart,
                                    lengthMinutes: clamped
                                ))
                        }

                        showAddSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveTemplate() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = DayTemplate(
            name: trimmed.isEmpty ? "New Day" : trimmed,
            startTime: startTime
        )
        modelContext.insert(template)

        let day = DayWindow(start: template.startTime)

        for draft in drafts {
            let start = TimeUtil.anchoredTime(
                draft.start, to: template.startTime)
            let minutes = DayScheduleEngine.clampDurationWithinDay(
                start: start,
                requestedMinutes: draft.lengthMinutes,
                day: day
            )

            let scheduled = ScheduledPlan(
                plan: draft.existingPlan,
                startTime: start,
                duration: TimeInterval(minutes * 60)
            )
            scheduled.dayTemplate = template
            modelContext.insert(scheduled)
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private func sortedDrafts() -> [PlanEntryDraft] {
        drafts.sorted { a, b in
            TimeUtil.anchoredTime(a.start, to: startTime)
                < TimeUtil.anchoredTime(b.start, to: startTime)
        }
    }

    private func deleteDrafts(at offsets: IndexSet) {
        var arr = sortedDrafts()
        for idx in offsets {
            let draft = arr[idx]
            if let realIdx = drafts.firstIndex(where: { $0.id == draft.id }) {
                drafts.remove(at: realIdx)
            }
        }
    }
}

// MARK: - Types

private enum AddPlanMode { case new, reuse }
