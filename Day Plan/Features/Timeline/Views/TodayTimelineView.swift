import SwiftData
import SwiftUI

/// Renders today's timeline for a given template ID.
/// Uses live `@Query` for the template and its scheduled plans to avoid
/// race conditions on first render (before a ModelContext is attached).
///
/// Architecture notes:
/// - View = layout/animation only. All time rules live in VM/engine.
/// - We render the **strict calendar day** [00:00, 24:00) via `DayWindow`.
struct TodayTimelineView: View {
    let templateID: UUID

    @StateObject private var vm: TodayTimelineViewModel

    // Live SwiftData queries. These are parameterized in init using the templateID.
    @Query private var templateResults: [DayTemplate]
    @Query private var scheduled: [ScheduledPlan]

    // UI
    private enum GutterMode: String, CaseIterable { case auto, show, hide }
    @State private var gutterMode: GutterMode = .auto

    /// TimelineView “tick” cadence. 1s feels live without being heavy.
    private let tick: TimeInterval = 1

    init(templateID: UUID) {
        self.templateID = templateID
        _vm = StateObject(
            wrappedValue: TodayTimelineViewModel(templateID: templateID)
        )

        // Fetch exactly this template (live-updating)
        _templateResults = Query(filter: #Predicate { $0.id == templateID })

        // Fetch this template's scheduled plans, sorted by start time (live-updating)
        _scheduled = Query(
            filter: #Predicate { $0.dayTemplate?.id == templateID },
            sort: [SortDescriptor(\ScheduledPlan.startTime, order: .forward)]
        )
    }

    var body: some View {
        Group {
            if templateResults.first != nil {
                // We intentionally *don’t* rely on any stored “day start”.
                // The day window is the strict calendar day containing "now".
                let window = vm.dayWindow()

                TimelineView(.periodic(from: .now, by: tick)) { context in
                    let plans = scheduled

                    // Keep TimelineView's clock inside today's visible domain
                    // while preserving the current time-of-day.
                    let now = vm.anchoredNow(
                        context.date, dayStart: window.start, dayEnd: window.end
                    )

                    // Decide when to show the vertical spine automatically:
                    // - Always show if user forces it
                    // - Auto-hide once the day has fully completed
                    let projectedEnds = plans.map {
                        vm.projectedEnd(for: $0, in: window)
                    }
                    let lastEndToday = projectedEnds.max() ?? window.start
                    let dayComplete = now >= lastEndToday
                    let showSpine =
                        (gutterMode == .show)
                        || (gutterMode == .auto && !dayComplete)

                    if plans.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                // BEFORE FIRST PLAN gap:
                                // If "now" is before the first plan, show minutes till it starts.
                                if let first = plans.first,
                                    now < first.startTime
                                {
                                    let minsLeft = max(
                                        0,
                                        Int(
                                            first.startTime.timeIntervalSince(
                                                now) / 60)
                                    )
                                    TimelineGapRow(
                                        minutesUntil: minsLeft,
                                        showSpine: showSpine,
                                        kind: .beforeFirst
                                    )
                                }

                                // PLANS
                                ForEach(plans.indices, id: \.self) { i in
                                    let sp = plans[i]

                                    // Neighbor color hints for vertical spine blending.
                                    let topFrom: Color? =
                                        (i > 0)
                                        ? vm.outputColor(
                                            for: plans[i - 1], now: now) : nil
                                    let bottomTo: Color? =
                                        (i < plans.count - 1)
                                        ? vm.outputColor(
                                            for: plans[i + 1], now: now) : nil

                                    TimelineSpineRow(
                                        sp: sp,
                                        isFirst: i == 0,
                                        isLast: i == plans.count - 1,
                                        // NOTE: This prop is legacy in the row view; it’s not used there.
                                        // Passing `window.start` keeps call sites stable until you drop the prop.
                                        dayStart: window.start,
                                        now: now,
                                        showSpine: showSpine,
                                        topFromColor: topFrom,
                                        bottomToColor: bottomTo
                                    )

                                    // BETWEENERS (gaps between plan i and i+1)
                                    if i < plans.count - 1 {
                                        let next = plans[i + 1]
                                        if now >= sp.endTime
                                            && now < next.startTime
                                        {
                                            let minsLeft = max(
                                                0,
                                                Int(
                                                    next.startTime
                                                        .timeIntervalSince(now)
                                                        / 60)
                                            )
                                            TimelineGapRow(
                                                minutesUntil: minsLeft,
                                                showSpine: showSpine
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .scrollIndicators(.never)

                    }
                }
            } else {
                // While the live query warms up at app launch, avoid a scary "deleted" message.
                // Show a lightweight placeholder for a brief moment; if truly missing, it will persist.
                ContentUnavailableView("Loading…", systemImage: "clock")
                    .transition(.opacity)
            }
        }
        // Keep scroll state per template
        .id(templateID)
    }

    // MARK: - Empty state

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
