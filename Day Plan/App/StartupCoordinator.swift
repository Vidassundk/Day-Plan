import SwiftData
import SwiftUI

/// Decides what to show on launch: onboarding or the main app.
struct StartupCoordinator: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = OnboardingStateStore()

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                ContentView().accentColor(.green)  // your main dashboard
            } else {
                OnboardingView()
            }
        }
    }
}
