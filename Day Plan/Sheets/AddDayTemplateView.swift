import SwiftData
import SwiftUI

struct AddDayTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var showWeekScheduleFromHere: Bool
    init(showWeekScheduleFromHere: Binding<Bool> = .constant(false)) {
        _showWeekScheduleFromHere = showWeekScheduleFromHere
    }

    @State private var name: String = ""
    @State private var startTime: Date = Calendar.current.startOfDay(for: .now)

    @State private var drafts: [PlanEntryDraft] = []
    @State private var showingQuickAdd = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Template Name", text: $name)

                    DatePicker(
                        "Start time",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: startTime) { _ in
                        // If Day Start changes, push all drafts forward to remain valid
                        reflowDraftsForNewDayStart()
                    }
                }

                Section {
                    if drafts.isEmpty {
                        ContentUnavailableView(
                            "No plans yet", systemImage: "list.bullet.rectangle"
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(sortedDrafts()) { draft in
                            HStack(spacing: 12) {
                                Text(
                                    draft.existingPlan.emoji.isEmpty
                                        ? "🧩" : draft.existingPlan.emoji
                                )
                                .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(draft.existingPlan.title).font(.body)

                                    if let desc = draft.existingPlan
                                        .planDescription, !desc.isEmpty
                                    {
                                        Text(desc).foregroundStyle(.secondary)
                                            .font(.caption)
                                    }

                                    // Preview start–end and length
                                    let anchoredStart = TimeUtil.anchoredTime(
                                        draft.start, to: startTime)
                                    let end = anchoredStart.addingTimeInterval(
                                        TimeInterval(draft.lengthMinutes * 60))
                                    Text(
                                        "\(anchoredStart.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) (\(TimeUtil.formatMinutes(draft.lengthMinutes)))"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .onDelete { drafts.remove(atOffsets: $0) }
                    }
                } header: {
                    HStack {
                        Text("Plans for this day")
                        Spacer()
                        Button {
                            showingQuickAdd = true
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .navigationTitle("New Day Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveTemplate)
                        .disabled(
                            name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddPlanSheet(
                    dayStart: startTime,
                    earliestStart: earliestAvailableStart(),
                    remainingMinutes: remainingMinutesToday(),
                    onAdd: { drafts.append($0) }
                )
            }
        }
    }

    // MARK: - Persist DayTemplate + all scheduled plans
    private func saveTemplate() {
        let template = DayTemplate(name: name, startTime: startTime)
        modelContext.insert(template)

        let day = DayWindow(start: template.startTime)

        for draft in sortedDrafts() {
            let start = max(
                TimeUtil.anchoredTime(draft.start, to: day.start), day.start)
            guard start < day.end else { continue }

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
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Timing helpers (via SchedulingKit)

    /// Current drafts sorted by anchored start within this Day.
    private func sortedDrafts() -> [PlanEntryDraft] {
        drafts.sorted {
            TimeUtil.anchoredTime($0.start, to: startTime)
                < TimeUtil.anchoredTime($1.start, to: startTime)
        }
    }

    /// Earliest slot available: end of last scheduled draft (or day start if none).
    private func earliestAvailableStart() -> Date {
        DayScheduleEngine.earliestAvailableStart(
            day: DayWindow(start: startTime),
            items: drafts,
            getStart: { $0.start },
            getDuration: { TimeInterval($0.lengthMinutes * 60) }
        )
    }

    /// Minutes remaining in this 24h cycle (from Day start).
    private func remainingMinutesToday() -> Int {
        DayScheduleEngine.remainingMinutes(
            day: DayWindow(start: startTime),
            items: drafts,
            getStart: { $0.start },
            getDuration: { TimeInterval($0.lengthMinutes * 60) }
        )
    }

    /// When Day Start changes, enforce:
    ///  - first draft starts >= day start
    ///  - each next starts >= previous end
    ///  - clamp to 24h window
    private func reflowDraftsForNewDayStart() {
        drafts = DayScheduleEngine.reflow(
            day: DayWindow(start: startTime),
            items: drafts,
            getStart: { $0.start },
            getDuration: { TimeInterval($0.lengthMinutes * 60) },
            setStart: { $0.start = $1 },
            setDuration: { $0.lengthMinutes = Int($1 / 60) }
        )
    }
}

// MARK: - Quick Add Sheet with validation & 24h cap
private struct QuickAddPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    enum Mode: String, CaseIterable {
        case create = "Create New"
        case reuse = "Reuse Existing"
    }

    let dayStart: Date
    let earliestStart: Date  // computed by parent from existing drafts
    let remainingMinutes: Int  // minutes left in this 24h window
    let onAdd: (PlanEntryDraft) -> Void

    @State private var mode: Mode = .create

    // Start time (compact picker) — defaults to earliest available slot
    @State private var start: Date

    // Length (binds to minutes directly via reusable picker)
    @State private var lengthMinutes: Int

    // Create-new fields
    @State private var title: String = ""
    @State private var emoji: String = ""
    @State private var description: String = ""

    // Reuse-existing
    @Query(sort: \Plan.title) private var allPlans: [Plan]
    @State private var selectedPlanId: UUID?

    init(
        dayStart: Date, earliestStart: Date, remainingMinutes: Int,
        onAdd: @escaping (PlanEntryDraft) -> Void
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
                                ForEach(allPlans) { plan in
                                    Text("\(plan.emoji) \(plan.title)").tag(
                                        Optional(plan.id))
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

                    // Start (compact) — clamp to earliest/dayStart
                    DatePicker(
                        "Start", selection: $start,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: start) { newValue in
                        let anchored = TimeUtil.anchoredTime(
                            newValue, to: dayStart)
                        let minAllowed = max(dayStart, earliestStart)
                        if anchored < minAllowed { start = minAllowed }
                    }

                    // Length (compact-style minutes picker)
                    LengthPicker(
                        "Length", minutes: $lengthMinutes,
                        initialMinutes: max(5, min(30, remainingMinutes))
                    )
                    .disabled(remainingMinutes <= 0)

                    // Live preview
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
                        .font(.footnote)
                        .foregroundStyle(.red)
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
                        let draft = buildDraft()
                        onAdd(draft)
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
        case .reuse:
            return selectedPlanId != nil
        }
    }

    private func buildDraft() -> PlanEntryDraft {
        // Clamp start against dayStart and earliestStart
        let clampedStart = max(
            TimeUtil.anchoredTime(start, to: dayStart),
            max(dayStart, earliestStart)
        )

        // Clamp length within the 24h window from the chosen start
        let clampedLen = DayScheduleEngine.clampDurationWithinDay(
            start: clampedStart,
            requestedMinutes: lengthMinutes,
            day: DayWindow(start: dayStart)
        )

        switch mode {
        case .create:
            // Auto-save newly created plan for future reuse
            let plan = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                planDescription: description.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ? nil : description,
                emoji: emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty ? "🧩" : emoji
            )
            modelContext.insert(plan)
            try? modelContext.save()

            return PlanEntryDraft(
                existingPlan: plan, start: clampedStart,
                lengthMinutes: clampedLen)

        case .reuse:
            let plan = allPlans.first(where: { $0.id == selectedPlanId! })!
            return PlanEntryDraft(
                existingPlan: plan, start: clampedStart,
                lengthMinutes: clampedLen)
        }
    }
}
