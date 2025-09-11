import SwiftData
import SwiftUI

@main
struct Day_PlanApp: App {
    var body: some Scene {
        WindowGroup {
            StartupCoordinator()  // ← instead of ContentView()
        }
        .modelContainer(for: [
            DayTemplate.self,
            Plan.self,
            ScheduledPlan.self,
            WeekdayAssignment.self,
        ])
    }
}
