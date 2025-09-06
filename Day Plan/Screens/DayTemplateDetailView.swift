import SwiftData
import SwiftUI

extension ModelContext {
    func scheduledPlan(with id: UUID) -> ScheduledPlan? {
        let fd = FetchDescriptor<ScheduledPlan>(
            predicate: #Predicate { $0.id == id })
        return try? fetch(fd).first
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}

struct DayTemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: DayTemplate
    @State private var showingAdd = false
    @State private var editing: ScheduledPlan?
    @State private var editingID: UUID?

    private func delete(at offsets: IndexSet) {
        let items = sortedPlans
        for index in offsets { modelContext.delete(items[index]) }
        try? modelContext.save()
    }

    var body: some View {
        Form {
            // Template name
            Section("Template") {
                TextField("Name", text: $template.name)
            }

            Section("Plans") {
                let ids = sortedPlans.map(\.id)
                ForEach(ids, id: \.self) { spID in
                    if let sp = modelContext.scheduledPlan(with: spID) {
                        Button {
                            editingID = spID
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(sp.plan?.emoji ?? "🧩")
                                    Text(sp.plan?.title ?? "Untitled")
                                }
                                Text(rowSubtitle(for: sp))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                modelContext.delete(sp)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let toDelete = offsets.map { ids[$0] }
                    toDelete.compactMap { modelContext.scheduledPlan(with: $0) }
                        .forEach { modelContext.delete($0) }
                    try? modelContext.save()
                }
            }
            .sheet(item: $editingID) { spID in
                if let sp = modelContext.scheduledPlan(with: spID) {
                    EditScheduledPlanSheet(
                        template: template,
                        planToEdit: sp,
                        onSaved: { try? modelContext.save() },
                        onDelete: {
                            modelContext.delete(sp)
                            try? modelContext.save()
                        }
                    )
                } else {
                    // Deleted meanwhile – nothing to edit
                    EmptyView()
                }
            }

            // 🔹 Add button moved below the list
            Section {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Plan", systemImage: "plus")
                }
                // if you want a centered look:
                // .frame(maxWidth: .infinity, alignment: .center)
                // or wrap in HStack { Spacer(); Label(...); Spacer() }
            }
        }

        // Add sheet (unchanged)
        .sheet(isPresented: $showingAdd) {
            AddOrReusePlanSheet(anchorDay: template.dayStart) {
                plan, start, lengthMinutes in
                if template.scheduledPlans.isEmpty {
                    template.startTime = start
                }
                let anchored = TimeUtil.anchoredTime(
                    start, to: template.startTime)
                let sp = ScheduledPlan(
                    plan: plan,
                    startTime: anchored,
                    duration: TimeInterval(lengthMinutes * 60)
                )
                modelContext.insert(sp)  // ensure it's in the context
                template.scheduledPlans.append(sp)  // mutate the parent array
                sp.dayTemplate = template
                try? modelContext.save()
            }
        }

        // Edit sheet (unchanged)
        .sheet(item: $editing) { sp in
            EditScheduledPlanSheet(
                template: template,
                planToEdit: sp,
                onSaved: { try? modelContext.save() },
                onDelete: {
                    modelContext.delete(sp)
                    try? modelContext.save()
                }
            )
        }
        .onDisappear { try? modelContext.save() }
    }

    // MARK: - Helpers

    private func delete(_ sp: ScheduledPlan) {
        modelContext.delete(sp)
        try? modelContext.save()
    }

    private var sortedPlans: [ScheduledPlan] {
        template.scheduledPlans.sorted { $0.startTime < $1.startTime }
    }

    private func rowSubtitle(for sp: ScheduledPlan) -> String {
        let start = sp.startTime
        let end = sp.startTime.addingTimeInterval(sp.duration)
        let mins = Int(sp.duration / 60)
        return
            "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(mins))"
    }
}
