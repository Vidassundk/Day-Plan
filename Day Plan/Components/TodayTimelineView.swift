// PATCH 1/2 — TodayTimelineView.swift
// Choose ONE primary current item among overlapping "current" plans.
// The *last* active plan (by start time) is considered primary.

import SwiftData
import SwiftUI

struct TodayTimelineView: View {
    let template: DayTemplate

    @State private var gutterMode: GutterMode = .auto
    private enum GutterMode: String, CaseIterable, Hashable {
        case auto, show, hide
    }

    private var plans: [ScheduledPlan] {
        (template.scheduledPlans ?? []).sorted { $0.startTime < $1.startTime }
    }

    private var dayStart: Date { template.startTime }
    private var dayEnd: Date { dayStart.addingTimeInterval(24 * 60 * 60) }
    private let tick: TimeInterval = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            //            controlRow

            TimelineView(.periodic(from: .now, by: tick)) { context in
                let anchoredNow = TimeUtil.anchoredTime(
                    context.date, to: dayStart)
                let now = min(max(anchoredNow, dayStart), dayEnd)

                // Day completion and gutter visibility
                let lastEnd =
                    plans.last.map {
                        $0.startTime.addingTimeInterval($0.duration)
                    } ?? dayStart
                let dayComplete = now >= lastEnd
                let showSpine: Bool = {
                    switch gutterMode {
                    case .show: return true
                    case .hide: return false
                    case .auto: return !dayComplete
                    }
                }()

                // Primary current index among overlaps (last-starting wins)
                let activeIndices = plans.indices.filter { i in
                    let sp = plans[i]
                    let end = sp.startTime.addingTimeInterval(sp.duration)
                    return now >= sp.startTime && now < end
                }
                let primaryActiveIndex = activeIndices.last

                TimelineList(
                    plans: plans,
                    dayStart: dayStart,
                    now: now,
                    showSpine: showSpine,
                    primaryActiveIndex: primaryActiveIndex
                )
            }
        }
    }

    // MARK: - Pieces

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

    private struct TimelineList: View {
        let plans: [ScheduledPlan]
        let dayStart: Date
        let now: Date
        let showSpine: Bool
        let primaryActiveIndex: Int?

        var body: some View {
            if plans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // NEW: pre-first gap row
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
                            TimelineSpineRow(
                                sp: sp,
                                isFirst: i == 0,
                                isLast: i == plans.count - 1,
                                dayStart: dayStart,
                                now: now,
                                showSpine: showSpine,
                                isPrimaryCurrent: (i == primaryActiveIndex)
                            )

                            // Insert an in-between row when NOW is between this plan's end and the next plan's start.
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
    import SwiftUI

    struct TodayTimelineView_Previews: PreviewProvider {
        static var previews: some View {
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: .now)

            // Sample Plans (kept minimal here; your real preview seeds much more)
            let a = Plan(
                title: "Standup", planDescription: "Sprint 42", emoji: "👥")
            let b = Plan(
                title: "Design Sync", planDescription: "Typography", emoji: "🎨")
            let c = Plan(
                title: "Lunch", planDescription: "Chicken salad", emoji: "🥗")
            let d = Plan(
                title: "Workout", planDescription: "Push day", emoji: "💪")

            let plans: [ScheduledPlan] = [
                .init(
                    plan: a,
                    startTime: cal.date(
                        byAdding: .hour, value: 8, to: startOfDay)!,
                    duration: 45 * 60),
                .init(
                    plan: b,
                    startTime: cal.date(
                        byAdding: .hour, value: 10, to: startOfDay)!,
                    duration: 75 * 60),
                .init(
                    plan: c,
                    startTime: cal.date(
                        byAdding: .hour, value: 13, to: startOfDay)!,
                    duration: 60 * 60),
                .init(
                    plan: d,
                    startTime: cal.date(
                        byAdding: .hour, value: 16, to: startOfDay)!,
                    duration: 30 * 60),
            ]

            let template = DayTemplate(
                name: "Sample Day", startTime: startOfDay)
            template.scheduledPlans = plans

            return TodayTimelineView(template: template)
                .previewDisplayName("TodayTimelineView — Primary current spine")
        }
    }
#endif
