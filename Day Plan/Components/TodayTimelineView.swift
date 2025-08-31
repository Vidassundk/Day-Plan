import SwiftData
import SwiftUI

struct TodayTimelineView: View {
    let template: DayTemplate

    private var plans: [ScheduledPlan] {
        (template.scheduledPlans ?? []).sorted { $0.startTime < $1.startTime }
    }

    private var dayStart: Date { template.startTime }
    private var dayEnd: Date { dayStart.addingTimeInterval(24 * 60 * 60) }
    private let tick: TimeInterval = 1

    var body: some View {
        TimelineView(.periodic(from: .now, by: tick)) { context in
            let anchoredNow = TimeUtil.anchoredTime(context.date, to: dayStart)
            let now = min(max(anchoredNow, dayStart), dayEnd)

            if plans.isEmpty {
                ContentUnavailableView(
                    "No plans scheduled today", systemImage: "clock")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(plans.indices, id: \.self) { i in
                            let sp = plans[i]
                            TimelineSpineRow(
                                sp: sp,
                                isFirst: i == 0,
                                isLast: i == plans.count - 1,
                                dayStart: dayStart,
                                now: now
                            )
                            .animation(.easeInOut(duration: 0.25), value: now)
                        }
                    }
                    .padding(.vertical, 8)

                }
            }
        }
    }
}

#if DEBUG
    import SwiftUI

    struct TodayTimelineView_Previews: PreviewProvider {
        static var previews: some View {
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: .now)

            // Plans
            let standup = Plan(
                title: "Standup", planDescription: "Sprint 42", emoji: "👥")
            let design = Plan(
                title: "Design Sync", planDescription: "Typography", emoji: "🎨")
            let lunch = Plan(
                title: "Lunch", planDescription: "Chicken salad", emoji: "🥗")
            let gym = Plan(
                title: "Workout", planDescription: "Push day", emoji: "💪")

            let plans: [ScheduledPlan] = [
                .init(
                    plan: standup,
                    startTime: cal.date(
                        byAdding: .hour, value: 8, to: startOfDay)!,
                    duration: 45 * 60),
                .init(
                    plan: design,
                    startTime: cal.date(
                        byAdding: .hour, value: 10, to: startOfDay)!,
                    duration: 75 * 60),
                .init(
                    plan: lunch,
                    startTime: cal.date(
                        byAdding: .hour, value: 13, to: startOfDay)!,
                    duration: 60 * 60),
                .init(
                    plan: gym,
                    startTime: cal.date(
                        byAdding: .hour, value: 16, to: startOfDay)!,
                    duration: 30 * 60),
            ]

            // Your DayTemplate likely needs a name now:
            let template = DayTemplate(
                name: "Sample Day", startTime: startOfDay)
            template.scheduledPlans = plans

            return TodayTimelineView(template: template)
                .previewDisplayName("TodayTimelineView")
        }
    }
#endif
