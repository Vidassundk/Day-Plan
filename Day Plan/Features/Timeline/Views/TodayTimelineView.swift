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

    /// Keeps the full grid height for a moment after toggling to View mode,
    /// so the outer container doesn't snap shorter before child animations finish.
    @State private var keepGridFrameDuringCollapse: Bool = false

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
        TimelineView(.periodic(from: Date(), by: tick)) {
            (context: TimelineViewDefaultContext) in
            let now = context.date
            let plans = scheduled
            let isEditing = (mode == .edit)
            let showSpine = (mode == .view)
            let startDay = startOfDay(now)
            let endDay = endOfDay(now)
            let editMinuteHeight = TimelineStyle.editMinuteHeight

            VStack(alignment: .leading, spacing: 12) {
                header()

                ZStack(alignment: .topLeading) {
                    HourGrid(
                        isEditing: isEditing,
                        keepFrame: keepGridFrameDuringCollapse,
                        startOfDay: startDay,
                        minuteHeight: editMinuteHeight
                    )

                    ScrollView(.vertical) {
                        ZStack(alignment: .topLeading) {
                            SpineLayer(
                                now: now,
                                plans: plans,
                                showSpine: showSpine
                            )

                            CardsLayer(
                                now: now,
                                plans: plans,
                                isEditing: isEditing,
                                showSpine: showSpine,
                                startOfDay: startDay,
                                endOfDay: endDay,
                                minuteHeight: editMinuteHeight
                            )
                        }
                        .padding(.top, isEditing ? HoursGridLayer.topInset : 0)
                        .padding(.vertical, isEditing ? 0 : 8)
                    }
                    .scrollIndicators(.never)
                }
            }
            .onChange(of: mode) { newMode in
                if newMode == .view {
                    // Lock the grid frame so container height doesn't snap shorter immediately.
                    keepGridFrameDuringCollapse = true
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + TimelineStyle.cardRepositionDuration
                    ) {
                        keepGridFrameDuringCollapse = false
                    }
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

    // MARK: - Helper Layers (split to keep type-checker happy)

    @ViewBuilder
    private func HourGrid(
        isEditing: Bool,
        keepFrame: Bool,
        startOfDay: Date,
        minuteHeight: CGFloat
    ) -> some View {
        if isEditing || keepFrame {
            HoursGridLayer(minuteHeight: minuteHeight, start: startOfDay)
                .frame(
                    height: HoursGridLayer.requiredHeight(
                        minuteHeight: minuteHeight
                    )
                )
                .opacity(isEditing ? 1 : 0)  // keep frame, hide visuals when collapsing
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func SpineLayer(
        now: Date,
        plans: [ScheduledPlan],
        showSpine: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = plans.first, now < first.startTime {
                // Gap at the very top
                TimelineGapSpineRow(kind: .beforeFirst, showSpine: showSpine)
            }

            ForEach(plans.indices, id: \.self) { i in
                let sp = plans[i]

                // Gap between previous and current
                if i > 0 {
                    let prev = plans[i - 1]
                    if now >= prev.endTime && now < sp.startTime {
                        TimelineGapSpineRow(
                            kind: .between,
                            showSpine: showSpine
                        )
                    }
                }

                // Main spine segment for this plan
                TimelineSpineOnlyRow(
                    sp: sp,
                    isFirst: i == 0,
                    isLast: i == plans.count - 1,
                    now: now,
                    showSpine: showSpine,
                    isEditing: false,  // spines do not relocate in edit
                    editMinuteHeight: TimelineStyle.editMinuteHeight
                )
            }
        }
    }

    @ViewBuilder
    private func CardsLayer(
        now: Date,
        plans: [ScheduledPlan],
        isEditing: Bool,
        showSpine: Bool,
        startOfDay: Date,
        endOfDay: Date,
        minuteHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Spacer before the first plan
            if let first = plans.first {
                let lead = max(
                    0,
                    Int(first.startTime.timeIntervalSince(startOfDay) / 60)
                )
                let showFirstGapLabel = (!isEditing && now < first.startTime)
                let firstGapMinutes = max(
                    0,
                    Int(first.startTime.timeIntervalSince(now) / 60)
                )

                AnimHeightSpacer(
                    height: isEditing ? CGFloat(lead) * minuteHeight : 0,
                    animate: isEditing,
                    delay: 0,
                    duration: TimelineStyle.cardRepositionDuration
                )
                // In-flow label row so it reserves space (not overlay)
                GapLabelRow(
                    show: showFirstGapLabel,
                    minutes: firstGapMinutes,
                    showSpine: showSpine,
                    reserveGutter: isEditing || showSpine
                )
            }

            // Plans + gaps
            ForEach(plans.indices, id: \.self) { i in
                let sp = plans[i]

                if i > 0 {
                    let prev = plans[i - 1]
                    let gap = max(
                        0,
                        Int(sp.startTime.timeIntervalSince(prev.endTime) / 60)
                    )
                    let showBetweenGapLabel =
                        (!isEditing && now >= prev.endTime
                            && now < sp.startTime)
                    let betweenGapMinutes = max(
                        0,
                        Int(sp.startTime.timeIntervalSince(now) / 60)
                    )

                    // Spacer representing the time gap
                    AnimHeightSpacer(
                        height: isEditing ? CGFloat(gap) * minuteHeight : 0,
                        animate: isEditing,
                        delay: 0,
                        duration: TimelineStyle.cardRepositionDuration
                    )
                    // In-flow label row so it reserves space (not overlay)
                    GapLabelRow(
                        show: showBetweenGapLabel,
                        minutes: betweenGapMinutes,
                        showSpine: showSpine,
                        reserveGutter: isEditing || showSpine
                    )
                }

                // The actual plan card
                TimelineCardOnlyRow(
                    sp: sp,
                    isFirst: i == 0,
                    isLast: i == plans.count - 1,
                    now: now,
                    isEditing: isEditing,
                    editMinuteHeight: minuteHeight,
                    reserveGutter: isEditing || showSpine
                )
            }

            // Spacer after the last plan
            if let last = plans.last {
                let tail = max(
                    0,
                    Int(endOfDay.timeIntervalSince(last.endTime) / 60)
                )
                AnimHeightSpacer(
                    height: isEditing ? CGFloat(tail) * minuteHeight : 0,
                    animate: isEditing,
                    delay: 0,
                    duration: TimelineStyle.cardRepositionDuration
                )
            }
        }
    }

    // Mounted, in-flow label row:
    // - Reserves space (height)
    // - Fades quickly with the spine
    // - Slides left in sync with the spine so you don't see it traveling down
    @ViewBuilder
    private func GapLabelRow(
        show: Bool,
        minutes: Int,
        showSpine: Bool,
        reserveGutter: Bool
    ) -> some View {
        let rowHeight: CGFloat = 26  // match TimelineGapSpineRow height
        let dir: CGFloat = (TimelineStyle.spineHideDirection == .left) ? -1 : 1
        let offsetX: CGFloat =
            showSpine ? 0 : dir * TimelineStyle.hideSlideDistance

        TimelineGapCardRow(
            minutesUntil: minutes,
            isEditing: false,
            reserveGutter: reserveGutter,
            showSpine: showSpine
        )
        .frame(height: show ? rowHeight : 0)
        .opacity((show && showSpine) ? 1 : 0)  // vanish as soon as Edit starts
        .offset(x: offsetX)  // slide with the spine
        .animation(
            .easeInOut(duration: TimelineStyle.cardRepositionDuration),
            value: show
        )  // space collapse
        .animation(
            .easeInOut(duration: TimelineStyle.spineFadeDuration),
            value: showSpine
        )  // fade/slide with spine
        .animation(
            .easeInOut(duration: TimelineStyle.spineFadeDuration),
            value: show
        )  // fade when time-window flips
        .allowsHitTesting(false)
        .accessibilityHidden(!show)
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
