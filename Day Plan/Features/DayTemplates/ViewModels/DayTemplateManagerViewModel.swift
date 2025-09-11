import SwiftData
import SwiftUI

/// MVVM: Manages Day Template list actions for the manager screen.
@MainActor
final class DayTemplatesManagerViewModel: ObservableObject {
    /// Delete templates at provided offsets from a source array, then save.
    func deleteTemplates(
        from source: [DayTemplate], at offsets: IndexSet, in ctx: ModelContext
    ) {
        withAnimation {
            for idx in offsets { ctx.delete(source[idx]) }
            try? ctx.save()
        }
    }
}
