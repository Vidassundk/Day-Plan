import SwiftData
import SwiftUI

struct WeekScheduleView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WeekdayAssignment.weekdayRaw)
    private var assignments: [WeekdayAssignment]

    @Query(sort: \DayTemplate.name)
    private var templates: [DayTemplate]

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Day Templates yet",
                            systemImage: "calendar.badge.plus",
                            description: Text(
                                "Create a template first, then assign it to weekdays."
                            )
                        )
                    }
                }

                Section {
                    ForEach(Weekday.ordered, id: \.rawValue) { day in
                        let assn = assignment(for: day)  // ✅ create-on-demand
                        WeekdayAssignmentRow(
                            assignment: assn, templates: templates)
                    }
                } header: {
                    Text("Assign a template to each weekday")
                } footer: {
                    Text(
                        "One template per weekday. A template can be reused on multiple weekdays."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Week Schedule")
            .task(bootstrapAssignments)  // ✅ also run early, not only onAppear
        }
    }

    // MARK: - Ensure one row per weekday, and fetch/create on demand

    private func bootstrapAssignments() {
        var existing = Set(assignments.map { $0.weekdayRaw })
        for day in Weekday.ordered where !existing.contains(day.rawValue) {
            modelContext.insert(WeekdayAssignment(weekday: day))
            existing.insert(day.rawValue)
        }
        if modelContext.hasChanges { try? modelContext.save() }
    }

    /// Returns an existing assignment for `weekday`, or creates & returns it synchronously.
    private func assignment(for weekday: Weekday) -> WeekdayAssignment {
        if let found = assignments.first(where: {
            $0.weekdayRaw == weekday.rawValue
        }) {
            return found
        }
        let created = WeekdayAssignment(weekday: weekday)
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }
}

// MARK: - Row that owns its selection state, writes back to SwiftData

struct WeekdayAssignmentRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var assignment: WeekdayAssignment
    let templates: [DayTemplate]

    var body: some View {
        HStack {
            Text(assignment.weekday.name)
            Spacer()

            Picker(
                "Template",
                selection: Binding<UUID?>(
                    get: { assignment.template?.id },  // reflects nil when template is deleted
                    set: { newId in
                        assignment.template = templates.first { $0.id == newId }
                        try? modelContext.save()
                    }
                )
            ) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(templates) { tpl in
                    Text(tpl.name).tag(Optional(tpl.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .contentShape(Rectangle())
    }
}
