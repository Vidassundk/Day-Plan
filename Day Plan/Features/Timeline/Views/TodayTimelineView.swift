import SwiftData
import SwiftUI
import UIKit

/// Renders today's timeline for a given template ID.
/// View mode shows the classic spine; Edit mode overlays an hour grid and renders
/// cards at exact time heights, with time-accurate spacing between items.
struct TodayTimelineView: View {
    let templateID: UUID

    @Query private var scheduled: [ScheduledPlan]

    private enum Mode: String, CaseIterable {
        case view = "View"
        case edit = "Edit"
    }

    @State private var mode: Mode = .view

    private let tick: TimeInterval = 1

    init(templateID: UUID) {
        self.templateID = templateID
        _scheduled = Query(
            filter: #Predicate<ScheduledPlan> {
                $0.dayTemplate?.id == templateID
            },
            sort: [SortDescriptor(\ScheduledPlan.startTime, order: .forward)]
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: tick)) { timeline in
            let now = timeline.date
            let plans = scheduled
            let showSpine = (mode == .view)

            VStack(alignment: .leading, spacing: 12) {
                header()

                ZStack(alignment: .topLeading) {
                    if mode == .edit {
                        HoursGridLayer(
                            minuteHeight: TimelineStyle.editMinuteHeight,
                            start: startOfDay(now)
                        )
                        .frame(
                            height: HoursGridLayer.requiredHeight(
                                minuteHeight: TimelineStyle.editMinuteHeight
                            )
                        )
                    }

                    ScrollView(.vertical) {
                        ZStack(alignment: .topLeading) {

                            // ======================
                            // Spines layer (left)
                            // ======================
                            VStack(alignment: .leading, spacing: 0) {
                                if mode == .view, let first = plans.first,
                                    now < first.startTime
                                {
                                    TimelineGapSpineRow(kind: .beforeFirst)
                                }

                                ForEach(
                                    Array(plans.enumerated()),
                                    id: \.element.id
                                ) { i, sp in
                                    if mode == .view, i > 0 {
                                        let prev = plans[i - 1]
                                        if now >= prev.endTime
                                            && now < sp.startTime
                                        {
                                            TimelineGapSpineRow(kind: .between)
                                        }
                                    }

                                    TimelineSpineOnlyRow(
                                        sp: sp,
                                        isFirst: i == 0,
                                        isLast: i == plans.count - 1,
                                        now: now,
                                        showSpine: showSpine,
                                        isEditing: false,  // spines do not relocate in edit
                                        editMinuteHeight: TimelineStyle
                                            .editMinuteHeight
                                    )
                                }
                            }

                            // ======================
                            // Cards layer (right)
                            // ======================
                            VStack(alignment: .leading, spacing: 0) {
                                if let first = plans.first {
                                    let lead = max(
                                        0,
                                        Int(
                                            first.startTime.timeIntervalSince(
                                                startOfDay(now)
                                            ) / 60
                                        )
                                    )
                                    AnimHeightSpacer(
                                        height: (mode == .edit)
                                            ? CGFloat(lead)
                                                * TimelineStyle.editMinuteHeight
                                            : 0,
                                        animate: mode == .edit,
                                        delay: 0,
                                        duration: TimelineStyle
                                            .cardRepositionDuration
                                    )
                                    if mode == .view, now < first.startTime {
                                        let minsLeft = max(
                                            0,
                                            Int(
                                                first.startTime
                                                    .timeIntervalSince(now) / 60
                                            )
                                        )
                                        TimelineGapCardRow(
                                            minutesUntil: minsLeft,
                                            isEditing: false,
                                            reserveGutter: (mode == .edit)
                                                || showSpine
                                        )
                                        .transition(.opacity)
                                    }
                                }

                                ForEach(
                                    Array(plans.enumerated()),
                                    id: \.element.id
                                ) { i, sp in
                                    if i > 0 {
                                        let prev = plans[i - 1]
                                        let gap = max(
                                            0,
                                            Int(
                                                sp.startTime.timeIntervalSince(
                                                    prev.endTime
                                                ) / 60
                                            )
                                        )
                                        AnimHeightSpacer(
                                            height: (mode == .edit)
                                                ? CGFloat(gap)
                                                    * TimelineStyle
                                                    .editMinuteHeight : 0,
                                            animate: mode == .edit,
                                            delay: 0,
                                            duration: TimelineStyle
                                                .cardRepositionDuration
                                        )
                                        if mode == .view,
                                            now >= prev.endTime
                                                && now < sp.startTime
                                        {
                                            let minsLeft = max(
                                                0,
                                                Int(
                                                    sp.startTime
                                                        .timeIntervalSince(now)
                                                        / 60
                                                )
                                            )
                                            TimelineGapCardRow(
                                                minutesUntil: minsLeft,
                                                isEditing: false,
                                                reserveGutter: (mode == .edit)
                                                    || showSpine
                                            )
                                            .transition(.opacity)
                                        }
                                    }

                                    TimelineCardOnlyRow(
                                        sp: sp,
                                        isFirst: i == 0,
                                        isLast: i == plans.count - 1,
                                        now: now,
                                        isEditing: (mode == .edit),
                                        editMinuteHeight: TimelineStyle
                                            .editMinuteHeight,
                                        reserveGutter: (mode == .edit)
                                            || showSpine
                                    )
                                }

                                if let last = plans.last {
                                    let tail = max(
                                        0,
                                        Int(
                                            endOfDay(now).timeIntervalSince(
                                                last.endTime
                                            ) / 60
                                        )
                                    )
                                    AnimHeightSpacer(
                                        height: (mode == .edit)
                                            ? CGFloat(tail)
                                                * TimelineStyle.editMinuteHeight
                                            : 0,
                                        animate: mode == .edit,
                                        delay: 0,
                                        duration: TimelineStyle
                                            .cardRepositionDuration
                                    )
                                }
                            }
                        }
                        .padding(
                            .top,
                            mode == .edit ? HoursGridLayer.topInset : 0
                        )
                        .padding(.vertical, mode == .edit ? 0 : 8)
                    }
                    .scrollIndicators(.never)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header() -> some View {
        HStack(spacing: 12) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
        }
    }

    // MARK: - Time helpers

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    private func endOfDay(_ date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(date))
            ?? date
    }
}
