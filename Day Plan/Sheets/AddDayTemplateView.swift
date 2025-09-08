import SwiftData
import SwiftUI

/// Add a new Day Template with free-form plan times.
/// The 24h window anchor is the earliest draft plan start (or today 00:00 if empty).
struct AddDayTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var showWeekScheduleFromHere: Bool

    // Optional callback for the created template (used by WeekScheduleView fast-track)
    private let onSaved: ((DayTemplate) -> Void)?

    // Init — no start time prefill anymore
    init(
        showWeekScheduleFromHere: Binding<Bool> = .constant(false),
        prefillName: String? = nil,
        onSaved: ((DayTemplate) -> Void)? = nil
    ) {
        _showWeekScheduleFromHere = showWeekScheduleFromHere
        _name = State(initialValue: prefillName ?? "")
        self.onSaved = onSaved
    }

    @State private var name: String = ""

    // Drafts the user is assembling before saving
    @State private var drafts: [PlanEntryDraft] = []

    // Effective anchor for the 24h window while drafting
    private var draftDayAnchor: Date {
        let fallback = Calendar.current.startOfDay(for: .now)
        let earliest =
            drafts
            .map { TimeUtil.anchoredTime($0.start, to: fallback) }
            .min()
        return earliest ?? fallback
    }

    /// Clamp so that [start, start + minutes] lies within [anchor, anchor + 24h).
    private func clampWithinDay(
        start: Date, requestedMinutes: Int, anchor: Date
    ) -> Int {
        let endOfDay = anchor.addingTimeInterval(24 * 60 * 60)
        let maxSeconds = max(0, endOfDay.timeIntervalSince(start))
        return max(0, min(requestedMinutes, Int(maxSeconds / 60)))
    }

    @Query(sort: \Plan.title) private var allPlans: [Plan]

    // Add plan sheet state
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Template
                Section("Template") {
                    TextField("Name", text: $name)
                }

                // MARK: Plans
                Section("Plans") {
                    if drafts.isEmpty {
                        ContentUnavailableView(
                            "No plans yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text(
                                "Add a plan to start building this day.")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(sortedDrafts()) { draft in
                            draftRow(draft: draft)  // uses draftDayAnchor internally
                        }
                        .onDelete(perform: deleteDrafts)
                    }

                    Button {
                        showAddSheet = true
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
                AddOrReusePlanSheet(
                    anchorDay: draftDayAnchor,
                    initialStart: TimeUtil.anchoredTime(
                        .now, to: draftDayAnchor),
                    initialLengthMinutes: 60
                ) { plan, start, length in
                    let anchoredStart = TimeUtil.anchoredTime(
                        start, to: draftDayAnchor)
                    let clamped = clampWithinDay(
                        start: anchoredStart,
                        requestedMinutes: length,
                        anchor: draftDayAnchor
                    )
                    drafts.append(
                        PlanEntryDraft(
                            existingPlan: plan,
                            start: anchoredStart,
                            lengthMinutes: clamped
                        )
                    )
                }
            }

        }
    }

    // MARK: - Rows

    private func draftRow(draft: PlanEntryDraft) -> some View {
        let idx = drafts.firstIndex(where: { $0.id == draft.id })!
        let livePlan = modelContext.plan(with: draft.planID)

        let title = (livePlan?.title ?? draft.titleSnapshot)
        let emoji = (livePlan?.emoji ?? draft.emojiSnapshot)

        return HStack(spacing: 12) {
            Text(emoji.isEmpty ? "🧩" : emoji).font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title.isEmpty ? "Untitled" : title)
                    if livePlan == nil {
                        Text("Deleted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Timing display (anchored + clamped preview)
                let anchoredStart = TimeUtil.anchoredTime(
                    draft.start, to: draftDayAnchor)
                let clampedLen = clampWithinDay(
                    start: anchoredStart,
                    requestedMinutes: drafts[idx].lengthMinutes,
                    anchor: draftDayAnchor
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
                                newValue, to: draftDayAnchor)
                            drafts[idx].start = anchored
                            drafts[idx].lengthMinutes = clampWithinDay(
                                start: anchored,
                                requestedMinutes: drafts[idx].lengthMinutes,
                                anchor: draftDayAnchor
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
                            let anchored = TimeUtil.anchoredTime(
                                drafts[idx].start, to: draftDayAnchor)
                            drafts[idx].lengthMinutes = clampWithinDay(
                                start: anchored,
                                requestedMinutes: newLen,
                                anchor: draftDayAnchor
                            )
                        }
                    ),
                    initialMinutes: max(5, drafts[idx].lengthMinutes)
                )
            }
        }
        // Optional: let users swipe away drafts whose plan was deleted
        .swipeActions {
            if livePlan == nil {
                Button(role: .destructive) {
                    drafts.removeAll { $0.id == draft.id }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Save

    private func saveTemplate() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = DayTemplate(name: trimmed.isEmpty ? "New Day" : trimmed)
        modelContext.insert(template)

        // Persist using the earliest draft as anchor
        let saveAnchor = draftDayAnchor

        for draft in drafts {
            guard let plan = modelContext.plan(with: draft.planID) else {
                continue
            }

            let start = TimeUtil.anchoredTime(draft.start, to: saveAnchor)
            let minutes = clampWithinDay(
                start: start, requestedMinutes: draft.lengthMinutes,
                anchor: saveAnchor)

            let scheduled = ScheduledPlan(
                plan: plan,
                startTime: start,
                duration: TimeInterval(minutes * 60)
            )
            scheduled.dayTemplate = template
            modelContext.insert(scheduled)
        }

        try? modelContext.save()
        onSaved?(template)  // if used by WeekScheduleView
        dismiss()
    }

    // MARK: - Helpers

    private func sortedDrafts() -> [PlanEntryDraft] {
        drafts.sorted { a, b in
            TimeUtil.anchoredTime(a.start, to: draftDayAnchor)
                < TimeUtil.anchoredTime(b.start, to: draftDayAnchor)
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
