//
//  ContentView.swift
//  Day Plan
//
//  Created by Vidas Sun on 25/08/2025.
//

import Foundation
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Query for DayTemplates, sorted by name.
    @Query(sort: \DayTemplate.name) private var dayTemplates: [DayTemplate]

    // State to control the presentation of the "Add Template" sheet.
    @State private var isAddingTemplate = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(dayTemplates) { template in
                    NavigationLink {
                        // Navigate to a detail view for the selected template.
                        DayTemplateDetailView(template: template)
                    } label: {
                        Text(template.name)
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
            .navigationTitle("Day Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button {
                        isAddingTemplate.toggle()
                    } label: {
                        Label("Add Template", systemImage: "plus")
                    }
                }
            }
            // Present the sheet when isAddingTemplate is true.
            .sheet(isPresented: $isAddingTemplate) {
                AddDayTemplateView()
            }
        } detail: {
            Text("Select a Day Template")
        }
    }

    private func deleteTemplates(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(dayTemplates[index])
            }
        }
    }
}

#Preview {
    // Preview needs the container configured for all necessary models.
    let container = try! ModelContainer(
        for: DayTemplate.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return ContentView()
        .modelContainer(container)
}
