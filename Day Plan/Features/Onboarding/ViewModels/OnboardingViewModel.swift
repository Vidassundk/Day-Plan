import Foundation
import SwiftData

/// Drives the wizard. Keeps answers in the store as the user taps.
/// At the end, runs the seed once and marks onboarding as complete.
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: Int = 0  // 0..3

    let store: OnboardingStateStore
    private weak var context: ModelContext?

    init(store: OnboardingStateStore) {
        self.store = store
    }

    func attach(context: ModelContext) { self.context = context }

    func next() { step = min(step + 1, 3) }
    func back() { step = max(step - 1, 0) }

    func finish() {
        guard let ctx = context else { return }
        SeedService(context: ctx).generate(using: store)
        store.hasCompletedOnboarding = true
    }
}
