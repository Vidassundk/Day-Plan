import SwiftData
import SwiftUI

/// One screen for both creating a new DayTemplate and editing an existing one.
struct DayTemplateEditorView: View {
    enum Mode {
        case create(
            prefillName: String? = nil, onSaved: ((DayTemplate) -> Void)? = nil)
        case edit(_ template: DayTemplate)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    // Shared add-plan sheet state
    @State private var showAddSheet = false

    @State private var refreshID = UUID()

    // -------- CREATE MODE STATE --------
    @State private var name: String = ""
    @State private var drafts: [PlanEntryDraft] = []

    // Compute anchor day:
    // - Create: earliest draft start (or today 00:00 if empty)
    // - Edit: template.dayStart (existing behavior)
    private var anchorDay: Date {
        switch mode {
        case .create:
            let fallback = Calendar.current.startOfDay(for: .now)
            let earliest =
                drafts
                .map { TimeUtil.anchoredTime($0.start, to: fallback) }
                .min()
            return earliest ?? fallback
        case .edit(let template):
            return template.dayStart
        }
    }

    // Helper clamp using shared SchedulingKit implementation
    private func clampMinutes(start: Date, requestedMinutes: Int) -> Int {
        let window = DayWindow(start: anchorDay)
        return DayScheduleEngine.clampDurationWithinDay(
            start: start,
            requestedMinutes: requestedMinutes,
            day: window
        )
    }

    @Query(sort: \Plan.title) private var allPlans: [Plan]

    init(_ mode: Mode) {
        self.mode = mode
        if case let .create(prefillName, _) = mode {
            _name = State(initialValue: prefillName ?? "")
        }
    }

    /// Suggest the next start time = end of the latest block in the current mode.
    /// - Create: end of latest draft (clamped) or anchorDay if none
    /// - Edit:   end of latest scheduled plan or anchorDay if none
    private func suggestedInitialStart() -> Date {
        let anchor = anchorDay
        let endOfDay = anchor.addingTimeInterval(24 * 60 * 60)

        let lastEnd: Date = {
            switch mode {
            case .create:
                return drafts.map { d -> Date in
                    let start = TimeUtil.anchoredTime(d.start, to: anchor)
                    let clamped = clampMinutes(
                        start: start, requestedMinutes: d.lengthMinutes)
                    return start.addingTimeInterval(TimeInterval(clamped * 60))
                }.max() ?? anchor

            case .edit(let template):
                return template.scheduledPlans
                    .map { $0.startTime.addingTimeInterval($0.duration) }
                    .max() ?? anchor
            }
        }()

        // keep inside the same day; if it overflows, nudge to just before endOfDay
        return min(lastEnd, endOfDay.addingTimeInterval(-60))
    }

    var body: some View {
        content
            .sheet(isPresented: $showAddSheet) {
                let initial = suggestedInitialStart()
                AddOrReusePlanSheet(
                    anchorDay: anchorDay,
                    initialStart: TimeUtil.anchoredTime(initial, to: anchorDay),
                    initialLengthMinutes: 60
                ) { plan, start, length in
                    let anchoredStart = TimeUtil.anchoredTime(
                        start, to: anchorDay)
                    switch mode {
                    case .create:
                        let clamped = clampMinutes(
                            start: anchoredStart, requestedMinutes: length)
                        drafts.append(
                            PlanEntryDraft(
                                existingPlan: plan, start: anchoredStart,
                                lengthMinutes: clamped))
                        refreshID = UUID()  // 🔄 force list refresh in create mode

                    case .edit(let template):
                        let minutes = clampMinutes(
                            start: anchoredStart, requestedMinutes: length)
                        let scheduled = ScheduledPlan(
                            plan: plan, startTime: anchoredStart,
                            duration: TimeInterval(minutes * 60))
                        scheduled.dayTemplate = template
                        modelContext.insert(scheduled)
                        try? modelContext.save()
                        refreshID = UUID()
                    }
                }
            }
    }

    // MARK: - Content per mode
    @ViewBuilder
    private var content: some View {
        switch mode {
        case .create:
            NavigationStack {
                Form {
                    Section("Template") {
                        TextField("Name", text: $name)
                    }
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
                                draftRow(draft)
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
            }

        case .edit(let template):
            List {
                Section {
                    @Bindable var tpl = template
                    TextField("Template name", text: $tpl.name)
                } footer: {
                    Text(
                        "The day’s start is derived automatically from the earliest plan."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

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
                        ForEach(
                            template.scheduledPlans.sorted {
                                $0.startTime < $1.startTime
                            }
                        ) { sp in
                            scheduledRow(sp, template: template)
                        }
                        .onDelete { offsets in
                            deleteScheduledPlans(offsets, template: template)
                        }
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Plan", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(
                template.name.isEmpty ? "Day Template" : template.name
            )
            .navigationBarTitleDisplayMode(.inline)
            .id(refreshID)
        }
    }

    // MARK: - Draft rows (Create mode)
    private func draftRow(_ draft: PlanEntryDraft) -> some View {
        let idx = drafts.firstIndex(where: { $0.id == draft.id })!
        let livePlan = modelContext.plan(with: drafts[idx].planID)

        let title = (livePlan?.title ?? drafts[idx].titleSnapshot)
        let emoji = (livePlan?.emoji ?? drafts[idx].emojiSnapshot)

        let anchoredStart = TimeUtil.anchoredTime(
            drafts[idx].start, to: anchorDay)
        let clampedLen = clampMinutes(
            start: anchoredStart, requestedMinutes: drafts[idx].lengthMinutes)
        let end = anchoredStart.adding(minutes: clampedLen)

        return HStack(spacing: 12) {
            Text(emoji.isEmpty ? "🧩" : emoji).font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title.isEmpty ? "Untitled" : title)
                    if livePlan == nil {
                        Text("Deleted").font(.caption).foregroundStyle(
                            .secondary)
                    }
                }

                Text(
                    "\(anchoredStart.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(clampedLen))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                DatePicker(
                    "Start",
                    selection: Binding(
                        get: { drafts[idx].start },
                        set: { newValue in
                            let anchored = TimeUtil.anchoredTime(
                                newValue, to: anchorDay)
                            drafts[idx].start = anchored
                            drafts[idx].lengthMinutes = clampMinutes(
                                start: anchored,
                                requestedMinutes: drafts[idx].lengthMinutes
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
                                drafts[idx].start, to: anchorDay)
                            drafts[idx].lengthMinutes = clampMinutes(
                                start: anchored,
                                requestedMinutes: newLen
                            )
                        }
                    ),
                    initialMinutes: max(5, drafts[idx].lengthMinutes)
                )
            }
        }
        .swipeActions {
            if modelContext.plan(with: drafts[idx].planID) == nil {
                Button(role: .destructive) {
                    drafts.removeAll { $0.id == draft.id }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private func sortedDrafts() -> [PlanEntryDraft] {
        drafts.sorted {
            TimeUtil.anchoredTime($0.start, to: anchorDay)
                < TimeUtil.anchoredTime($1.start, to: anchorDay)
        }
    }

    private func deleteDrafts(at offsets: IndexSet) {
        var arr = sortedDrafts()
        for i in offsets {
            let d = arr[i]
            if let idx = drafts.firstIndex(where: { $0.id == d.id }) {
                drafts.remove(at: idx)
            }
        }
    }

    private func saveTemplate() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = DayTemplate(name: trimmed.isEmpty ? "New Day" : trimmed)
        modelContext.insert(template)

        let saveAnchor = anchorDay
        for draft in drafts {
            guard let plan = modelContext.plan(with: draft.planID) else {
                continue
            }
            let start = TimeUtil.anchoredTime(draft.start, to: saveAnchor)
            let minutes = clampMinutes(
                start: start, requestedMinutes: draft.lengthMinutes)
            let scheduled = ScheduledPlan(
                plan: plan, startTime: start,
                duration: TimeInterval(minutes * 60))
            scheduled.dayTemplate = template
            modelContext.insert(scheduled)
        }

        try? modelContext.save()

        if case let .create(_, onSaved) = mode {
            onSaved?(template)
        }
        dismiss()
    }

    // MARK: - Scheduled rows (Edit mode)
    private func scheduledRow(_ sp: ScheduledPlan, template: DayTemplate)
        -> some View
    {
        let startBinding = Binding<Date>(
            get: { sp.startTime },
            set: { newValue in
                let anchored = TimeUtil.anchoredTime(newValue, to: anchorDay)
                sp.startTime = anchored
                let minutes = clampMinutes(
                    start: anchored,
                    requestedMinutes: Int(sp.duration / 60)
                )
                sp.duration = TimeInterval(minutes * 60)
                try? modelContext.save()
            }
        )

        let minutesBinding = Binding<Int>(
            get: { max(0, Int(sp.duration / 60)) },
            set: { newLen in
                let anchored = TimeUtil.anchoredTime(
                    sp.startTime, to: anchorDay)
                let minutes = clampMinutes(
                    start: anchored, requestedMinutes: newLen)
                sp.startTime = anchored
                sp.duration = TimeInterval(minutes * 60)
                try? modelContext.save()
            }
        )

        let start = sp.startTime
        let end = sp.startTime.addingTimeInterval(sp.duration)
        let mins = Int(sp.duration / 60)

        return HStack(alignment: .top, spacing: 12) {
            let emoji = sp.plan?.emoji ?? ""
            Text(emoji.isEmpty ? "🧩" : emoji)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(sp.plan?.title ?? "Untitled").font(.headline)
                    if sp.plan == nil {
                        Text("Deleted").font(.caption).foregroundStyle(
                            .secondary)
                    }
                }

                Text(
                    "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(mins))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                DatePicker(
                    "Start", selection: startBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)

                LengthPicker(
                    "Length", minutes: minutesBinding,
                    initialMinutes: max(5, minutesBinding.wrappedValue))
            }
        }
    }

    private func deleteScheduledPlans(
        _ offsets: IndexSet, template: DayTemplate
    ) {
        let sorted = template.scheduledPlans.sorted {
            $0.startTime < $1.startTime
        }
        for idx in offsets {
            let sp = sorted[idx]
            modelContext.delete(sp)
        }
        try? modelContext.save()
    }
}
