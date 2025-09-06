// TodayTimelineView.swift
import SwiftData
import SwiftUI

struct TodayTimelineView: View {

    @Environment(\.modelContext) private var modelContext
    let templateID: UUID

    @State private var gutterMode: GutterMode = .auto
    private enum GutterMode: String, CaseIterable { case auto, show, hide }
    private let tick: TimeInterval = 1

    private func fetchTemplate() -> DayTemplate? {
        let fd = FetchDescriptor<DayTemplate>(
            predicate: #Predicate { $0.id == templateID })
        return try? modelContext.fetch(fd).first
    }

    private func fetchPlans() -> [ScheduledPlan] {
        let fd = FetchDescriptor<ScheduledPlan>(
            predicate: #Predicate { $0.dayTemplate?.id == templateID }
        )
        return
            (try? modelContext.fetch(fd).sorted { $0.startTime < $1.startTime })
            ?? []
    }

    var body: some View {
        Group {
            if let template = fetchTemplate() {
                let dayStart = template.startTime
                let dayEnd = dayStart.addingTimeInterval(24 * 60 * 60)

                TimelineView(.periodic(from: .now, by: tick)) { ctx in
                    let plans = fetchPlans()  // small dataset; refresh per tick
                    let anchoredNow = TimeUtil.anchoredTime(
                        ctx.date, to: dayStart)
                    let now = min(max(anchoredNow, dayStart), dayEnd)

                    let lastEnd =
                        plans.last.map {
                            $0.startTime.addingTimeInterval($0.duration)
                        } ?? dayStart
                    let dayComplete = now >= lastEnd
                    let showSpine: Bool =
                        (gutterMode == .show)
                        || (gutterMode == .auto && !dayComplete)

                    TimelineList(
                        plans: plans,
                        dayStart: dayStart,
                        now: now,
                        showSpine: showSpine
                    )
                }
            } else {
                ContentUnavailableView(
                    "Template deleted",
                    systemImage: "calendar.badge.exclamationmark")
            }
        }
        .id(templateID)
    }

    // MARK: - Optional controls (kept, not shown by default)
    private var controlRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Timeline gutter").font(.subheadline)
            Spacer(minLength: 8)
            Picker("", selection: $gutterMode) {
                Text("Auto").tag(GutterMode.auto)
                Text("Show").tag(GutterMode.show)
                Text("Hide").tag(GutterMode.hide)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .accessibilityLabel("Timeline gutter visibility")
        }
        .padding(.horizontal)
    }

    // MARK: - Inner list

    private struct TimelineList: View {
        let plans: [ScheduledPlan]
        let dayStart: Date
        let now: Date
        let showSpine: Bool

        // local status helper
        enum S { case past, current, upcoming }

        func status(of sp: ScheduledPlan) -> S {
            let start = sp.startTime
            let end = sp.startTime.addingTimeInterval(sp.duration)
            if now < start { return .upcoming }
            if now >= start && now < end { return .current }
            return .past
        }

        // The “output color” a row would paint into the spine (used as neighbor hint)
        // Matches the simplified rules:
        //   past -> .primary, current -> plan.tint, upcoming -> .separator
        func outputColor(for sp: ScheduledPlan) -> Color {
            switch status(of: sp) {
            case .past: return .primary
            case .current: return sp.plan?.tintColor ?? .accentColor
            case .upcoming: return Color(uiColor: .separator)
            }
        }

        var body: some View {
            if plans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Before-first gap
                        if let first = plans.first, now < first.startTime {
                            let minsLeft = max(
                                0,
                                Int(first.startTime.timeIntervalSince(now) / 60)
                            )
                            TimelineGapRow(
                                minutesUntil: minsLeft,
                                showSpine: showSpine,
                                kind: .beforeFirst
                            )
                        }

                        ForEach(plans.indices, id: \.self) { i in
                            let sp = plans[i]
                            let st = status(of: sp)

                            // Neighbor blend hints
                            let topFrom: Color? = {
                                guard i > 0 else { return nil }
                                return outputColor(for: plans[i - 1])
                            }()

                            let bottomTo: Color? = {
                                guard i < plans.count - 1 else { return nil }
                                return outputColor(for: plans[i + 1])
                            }()

                            TimelineSpineRow(
                                sp: sp,
                                isFirst: i == 0,
                                isLast: i == plans.count - 1,
                                dayStart: dayStart,
                                now: now,
                                showSpine: showSpine,
                                topFromColor: topFrom,
                                bottomToColor: bottomTo
                            )

                            // Between-plan gap if now lies between this plan's end and next plan's start
                            if i < plans.count - 1 {
                                let next = plans[i + 1]
                                let end = sp.startTime.addingTimeInterval(
                                    sp.duration)
                                if now >= end && now < next.startTime {
                                    let minsLeft = max(
                                        0,
                                        Int(
                                            next.startTime.timeIntervalSince(
                                                now) / 60))
                                    TimelineGapRow(
                                        minutesUntil: minsLeft,
                                        showSpine: showSpine)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }

        @ViewBuilder
        private var emptyState: some View {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    "No plans scheduled today", systemImage: "clock")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text("No plans scheduled today")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            }
        }
    }
}

#if DEBUG
    import SwiftData
    import SwiftUI

    struct TodayTimelineView_Previews: PreviewProvider {
        static var previews: some View {
            // In-memory container with a seeded template and a couple of plans
            let schema = Schema([
                DayTemplate.self, ScheduledPlan.self, Plan.self,
                WeekdayAssignment.self,
            ])
            let container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let ctx = container.mainContext
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: .now)

            let a = Plan(
                title: "Standup", planDescription: "Sprint 42", emoji: "👥")
            let b = Plan(title: "Design", planDescription: "Review", emoji: "🎨")
            let c = Plan(title: "Workout", planDescription: "Push", emoji: "💪")

            let sp1 = ScheduledPlan(
                plan: a,
                startTime: cal.date(byAdding: .hour, value: 9, to: startOfDay)!,
                duration: 45 * 60)
            let sp2 = ScheduledPlan(
                plan: b,
                startTime: cal.date(
                    byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 60 * 60)
            let sp3 = ScheduledPlan(
                plan: c,
                startTime: cal.date(
                    byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 90 * 60)

            let tpl = DayTemplate(name: "Sample Day", startTime: startOfDay)
            tpl.scheduledPlans = [sp1, sp2, sp3]
            sp1.dayTemplate = tpl
            sp2.dayTemplate = tpl
            sp3.dayTemplate = tpl

            ctx.insert(a)
            ctx.insert(b)
            ctx.insert(c)
            ctx.insert(sp1)
            ctx.insert(sp2)
            ctx.insert(sp3)
            ctx.insert(tpl)
            try? ctx.save()

            return TodayTimelineView(templateID: tpl.id)
                .modelContainer(container)
                .previewDisplayName("TodayTimelineView — simplified spine")
        }
    }
#endif
