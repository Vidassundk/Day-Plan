import SwiftData
import SwiftUI

/// Renders today's timeline for a given template ID.
/// MVVM: `TodayTimelineViewModel` provides template/plans + derived state.
struct TodayTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    let templateID: UUID

    @StateObject private var vm: TodayTimelineViewModel
    @State private var gutterMode: GutterMode = .auto
    private enum GutterMode: String, CaseIterable { case auto, show, hide }

    private let tick: TimeInterval = 1

    init(templateID: UUID) {
        self.templateID = templateID
        _vm = StateObject(
            wrappedValue: TodayTimelineViewModel(templateID: templateID))
    }

    var body: some View {
        Group {
            if let template = vm.template() {
                let bounds = vm.dayBounds(for: template)

                TimelineView(.periodic(from: .now, by: tick)) { context in
                    let plans = vm.plansSorted()  // small dataset; okay to refresh per tick
                    let now = vm.anchoredNow(
                        context.date, dayStart: bounds.start, dayEnd: bounds.end
                    )

                    let lastEnd = plans.last?.endTime ?? bounds.start
                    let dayComplete = now >= lastEnd
                    let showSpine =
                        (gutterMode == .show)
                        || (gutterMode == .auto && !dayComplete)

                    if plans.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {

                                // Before-first gap
                                if let first = plans.first,
                                    now < first.startTime
                                {
                                    let minsLeft = max(
                                        0,
                                        Int(
                                            first.startTime.timeIntervalSince(
                                                now) / 60))
                                    TimelineGapRow(
                                        minutesUntil: minsLeft,
                                        showSpine: showSpine, kind: .beforeFirst
                                    )
                                }

                                ForEach(plans.indices, id: \.self) { i in
                                    let sp = plans[i]

                                    // Neighbor colors for blend/junctions
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
                                        dayStart: bounds.start,
                                        now: now,
                                        showSpine: showSpine,
                                        topFromColor: topFrom,
                                        bottomToColor: bottomTo
                                    )

                                    // Gap between this plan's end and next plan's start (when we're in-between)
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
                                                        / 60))
                                            TimelineGapRow(
                                                minutesUntil: minsLeft,
                                                showSpine: showSpine)
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
                ContentUnavailableView(
                    "Template deleted",
                    systemImage: "calendar.badge.exclamationmark")
            }
        }
        .onAppear { vm.attach(context: modelContext) }
        .id(templateID)
    }

    // MARK: - Private

    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "No plans scheduled today", systemImage: "clock")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "clock")
                Text("No plans scheduled today").font(.callout).foregroundStyle(
                    .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        }
    }
}
