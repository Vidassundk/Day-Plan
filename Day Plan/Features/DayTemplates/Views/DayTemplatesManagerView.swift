import SwiftData
import SwiftUI

/// Screen: list, add, edit, delete Day Templates.
/// MVVM: `DayTemplatesManagerViewModel` handles destructive actions.
struct DayTemplateManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = DayTemplatesManagerViewModel()

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
                .onDelete { offsets in
                    vm.deleteTemplates(
                        from: dayTemplates, at: offsets, in: modelContext)
                }
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
        .sheet(isPresented: $isAddingTemplate) {
            DayTemplateEditorView(.create())
        }
    }
}

#if DEBUG
    import SwiftUI
    import SwiftData
    struct DayTemplateManagerView_Previews: PreviewProvider {
        static var previews: some View {
            let schema = Schema([
                DayTemplate.self, ScheduledPlan.self, Plan.self,
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
