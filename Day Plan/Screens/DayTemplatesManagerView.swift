// DayTemplateManagerView.swift
// Separate screen to manage Day Templates (list / add / edit / delete)

import SwiftData
import SwiftUI

struct DayTemplateManagerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DayTemplate.name) private var dayTemplates: [DayTemplate]

    @State private var isAddingTemplate = false

    var body: some View {
        List {
            if dayTemplates.isEmpty {
                ContentUnavailableView(
                    "No Day Templates",
                    systemImage: "square.on.square.dashed",
                    description: Text(
                        "Create your first template to start planning your day."
                    )
                )
            } else {
                ForEach(dayTemplates) { template in
                    NavigationLink {
                        DayTemplateEditorView(.edit(template))
                    } label: {
                        Text(template.name)
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
        }
        .navigationTitle("Day Templates")
        .toolbar {

            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            ToolbarItem {
                Button {
                    isAddingTemplate = true
                } label: {
                    Label("Add Template", systemImage: "plus")
                }
            }
        }
        // Keeping Add as a sheet is often nicer for quick entry; can be pushed if you prefer.
        .sheet(isPresented: $isAddingTemplate) {
            DayTemplateEditorView(.create())
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(dayTemplates[index]) }
            try? modelContext.save()
        }
    }
}

#if DEBUG
    import SwiftUI
    import SwiftData
    struct DayTemplateManagerView_Previews: PreviewProvider {
        static var previews: some View {
            let schema = Schema([
                DayTemplate.self,
                ScheduledPlan.self,
                Plan.self,
                WeekdayAssignment.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(
                for: schema, configurations: config)
            return NavigationStack { DayTemplateManagerView() }
                .modelContainer(container)
                .previewDisplayName("Template Manager")
        }
    }
#endif
