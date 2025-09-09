import SwiftData
import SwiftUI

/// Screen: create or edit a DayTemplate.
///
/// The ViewModel owns:
/// - create vs edit flow
/// - clamping logic (24h window that starts at the day's first plan)
/// - persistence
struct DayTemplateEditorView: View {
    enum Mode {
        case create(
            prefillName: String? = nil, onSaved: ((DayTemplate) -> Void)? = nil)
        case edit(_ template: DayTemplate)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @StateObject private var vm: DayTemplateEditorViewModel

    // Add-plan sheet
    @State private var showAddSheet = false

    init(_ mode: Mode) {
        self.mode = mode
        _vm = StateObject(wrappedValue: DayTemplateEditorViewModel(mode: mode))
    }

    var body: some View {
        content
            // Give VM its context once we’re mounted.
            .onAppear { vm.attach(context: modelContext) }
            // Reuse the same add sheet used elsewhere in the app.
            .sheet(isPresented: $showAddSheet) {
                let initial = vm.suggestedInitialStart()
                AddOrReusePlanSheet(
                    anchorDay: vm.anchorDay,
                    initialStart: TimeUtil.anchoredTime(
                        initial, to: vm.anchorDay),
                    initialLengthMinutes: 60
                ) { plan, start, length in
                    switch vm.mode {
                    case .create:
                        vm.appendDraft(
                            plan: plan, start: start, lengthMinutes: length)
                    case .edit(let templateID):
                        vm.addScheduled(
                            to: templateID, plan: plan, start: start,
                            lengthMinutes: length)
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
                        TextField("Name", text: $vm.name)
                    }

                    Section("Plans") {
                        if vm.drafts.isEmpty {
                            ContentUnavailableView(
                                "No plans yet",
                                systemImage: "list.bullet.rectangle",
                                description: Text(
                                    "Add a plan to start building this day.")
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(vm.sortedDrafts()) { draft in
                                draftRow(draft)
                            }
                            .onDelete(perform: vm.deleteDrafts)
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
                        Button("Save") {
                            _ = vm.saveTemplateCreate()
                            dismiss()
                        }
                        .disabled(vm.drafts.isEmpty)
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
                            scheduledRow(sp)
                        }
                        .onDelete { offsets in
                            vm.deleteScheduled(at: offsets, from: template)
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
            // Keep list in sync after inserts/deletes so ordering & rows stay fresh.
            .id(vm.refreshID)
        }
    }

    // MARK: - Rows

    /// Draft row (create mode).
    private func draftRow(_ draft: PlanEntryDraft) -> some View {
        // Keep a stable index back into `vm.drafts`.
        guard let idx = vm.drafts.firstIndex(where: { $0.id == draft.id })
        else {
            return EmptyView().eraseToAnyView()
        }

        // Show live Plan if it still exists, otherwise the stored snapshot.
        let livePlan = vm.livePlan(for: vm.drafts[idx].planID)
        let title = (livePlan?.title ?? vm.drafts[idx].titleSnapshot)
        let emoji = (livePlan?.emoji ?? vm.drafts[idx].emojiSnapshot)

        // Use anchored start for all time math within this day-window.
        let anchoredStart = TimeUtil.anchoredTime(
            vm.drafts[idx].start, to: vm.anchorDay)
        let maxAllowed = vm.maxSelectableMinutes(from: anchoredStart)

        let end = anchoredStart.addingTimeInterval(
            TimeInterval(vm.drafts[idx].lengthMinutes * 60))

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
                    "\(anchoredStart.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(vm.drafts[idx].lengthMinutes))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                // Start time: re-anchor + re-clamp when changed.
                DatePicker(
                    "Start",
                    selection: Binding(
                        get: { vm.drafts[idx].start },
                        set: { newValue in
                            let anchored = TimeUtil.anchoredTime(
                                newValue, to: vm.anchorDay)
                            vm.drafts[idx].start = anchored

                            // If start shifts, recompute the dynamic ceiling and re-clamp the current length.
                            let newMax = vm.maxSelectableMinutes(from: anchored)
                            vm.drafts[idx].lengthMinutes = min(
                                vm.clampMinutes(
                                    start: anchored,
                                    requestedMinutes: vm.drafts[idx]
                                        .lengthMinutes),
                                newMax
                            )
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)

                // Length: shared LengthPicker with a dynamic ceiling.
                // IMPORTANT: no .id tied to minutes — otherwise the compact popover closes on every tick.
                LengthPicker(
                    "Length",
                    minutes: Binding(
                        get: { vm.drafts[idx].lengthMinutes },
                        set: { newLen in
                            // VM still clamps (source of truth).
                            vm.drafts[idx].lengthMinutes = vm.clampMinutes(
                                start: anchoredStart,
                                requestedMinutes: newLen
                            )
                        }
                    ),
                    initialMinutes: vm.drafts[idx].lengthMinutes,
                    maxMinutes: maxAllowed
                )
            }
        }
        .eraseToAnyView()
    }

    /// Scheduled row (edit mode).
    private func scheduledRow(_ sp: ScheduledPlan) -> some View {
        let startBinding = Binding<Date>(
            get: { sp.startTime },
            set: { newValue in vm.updateScheduled(sp, newStart: newValue) }
        )

        let minutesBinding = Binding<Int>(
            get: { max(0, Int(sp.duration / 60)) },
            set: { newLen in vm.updateScheduled(sp, newMinutes: newLen) }
        )

        let start = sp.startTime
        let end = sp.endTime
        let mins = Int(sp.duration / 60)
        let maxAllowed = vm.maxSelectableMinutes(from: start)

        return HStack(alignment: .top, spacing: 12) {
            let emoji = sp.plan?.emoji ?? ""
            Text(emoji.isEmpty ? "🧩" : emoji).font(.title3)

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

                // Same fix here: do not put .id on minutes.
                LengthPicker(
                    "Length",
                    minutes: minutesBinding,
                    initialMinutes: mins,
                    maxMinutes: maxAllowed
                )
            }
        }
        .eraseToAnyView()
    }
}

// Small helper so we can `return EmptyView()` inside a conditional and still satisfy View builder.
extension View {
    fileprivate func eraseToAnyView() -> AnyView { AnyView(self) }
}
