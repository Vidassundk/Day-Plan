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
                    // Grid is ALWAYS mounted; we just fade/slide it opposite the spine.
                    HourGrid(
                        showSpine: showSpine,
                        startOfDay: startDay,
                        minuteHeight: editMinuteHeight
                    )

                    ScrollView(.vertical) {
                        ZStack(alignment: .topLeading) {
                            // Left column: spines and GAP TEXT overlay (fixed view-mode geometry)
                            SpineLayer(
                                now: now,
                                plans: plans,
                                showSpine: showSpine
                            )
                            GapTextSpineLayer(
                                now: now,
                                plans: plans,
                                showSpine: showSpine
                            )

                            // Right column: cards + in-flow (textless) gap rows for spacing
                            CardsLayer(
                                now: now,
                                plans: plans,
                                isEditing: isEditing,
                                startOfDay: startDay,
                                endDay: endDay,
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
                    // This can remain (harmless) for container-height stability;
                    // the grid is now always mounted so there’s no visual blink.
                    keepGridFrameDuringCollapse = true
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + TimelineStyle.cardRepositionDuration
                    ) {
                        keepGridFrameDuringCollapse = false
                    }
                }
            }

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

    /// Grid is always mounted; it fades/slides opposite to the spine.
    @ViewBuilder
    private func HourGrid(
        showSpine: Bool,
        startOfDay: Date,
        minuteHeight: CGFloat
    ) -> some View {
        // Counter-slide relative to the spine
        let hide = TimelineStyle.hideSlideDistance
        let dir: CGFloat = (TimelineStyle.spineHideDirection == .left) ? -1 : 1
        let spineHideOffset = dir * hide  // where the spine goes when it hides
        let gridHiddenOffset = -spineHideOffset  // opposite direction for the grid

        HoursGridLayer(minuteHeight: minuteHeight, start: startOfDay)
            .frame(
                height: HoursGridLayer.requiredHeight(
                    minuteHeight: minuteHeight
                )
            )
            .opacity(showSpine ? 0 : 1)  // inverse of spine
            .offset(x: showSpine ? gridHiddenOffset : 0)  // slide opposite direction
            .animation(
                .easeInOut(duration: TimelineStyle.spineFadeDuration),
                value: showSpine
            )
            .allowsHitTesting(false)
    }

    /// Left-side spines (fixed view-mode geometry).
    @ViewBuilder
    private func SpineLayer(now: Date, plans: [ScheduledPlan], showSpine: Bool)
        -> some View
    {
        VStack(alignment: .leading, spacing: 0) {
            if let first = plans.first, now < first.startTime {
                TimelineGapSpineRow(kind: .beforeFirst, showSpine: showSpine)
            }

            ForEach(plans.indices, id: \.self) { i in
                let sp = plans[i]

                if i > 0 {
                    let prev = plans[i - 1]
                    if now >= prev.endTime && now < sp.startTime {
                        TimelineGapSpineRow(
                            kind: .between,
                            showSpine: showSpine
                        )
                    }
                }

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

    /// Left-side *gap text* overlay that follows the same fixed view-mode stacking as the spine.
    @ViewBuilder
    private func GapTextSpineLayer(
        now: Date,
        plans: [ScheduledPlan],
        showSpine: Bool
    ) -> some View {
        let rowHeight =
            TimelineStyle.viewModeRowHeight
            + (TimelineStyle.cardVerticalPadView * 2)
        VStack(alignment: .leading, spacing: 0) {
            // Before-first gap label
            if let first = plans.first, now < first.startTime {
                let minsLeft = max(
                    0,
                    Int(first.startTime.timeIntervalSince(now) / 60)
                )
                TimelineGapCardRow(
                    minutesUntil: minsLeft,
                    isEditing: false,
                    reserveGutter: true,
                    showSpine: showSpine
                )
                .opacity(showSpine ? 1 : 0)
                .animation(
                    .easeInOut(duration: TimelineStyle.spineFadeDuration),
                    value: showSpine
                )
                .transition(.opacity)
            }

            // For each plan: optional between-gap label + fixed-height spacer matching the spine row
            ForEach(plans.indices, id: \.self) { i in
                let sp = plans[i]
                if i > 0 {
                    let prev = plans[i - 1]
                    if now >= prev.endTime && now < sp.startTime {
                        let minsLeft = max(
                            0,
                            Int(sp.startTime.timeIntervalSince(now) / 60)
                        )
                        TimelineGapCardRow(
                            minutesUntil: minsLeft,
                            isEditing: false,
                            reserveGutter: true,
                            showSpine: showSpine
                        )
                        .opacity(showSpine ? 1 : 0)
                        .animation(
                            .easeInOut(
                                duration: TimelineStyle.spineFadeDuration
                            ),
                            value: showSpine
                        )
                        .transition(.opacity)
                    }
                }

                // Advance the vertical stacking by the fixed view-mode row height (spine never stretches)
                Color.clear.frame(height: rowHeight)
            }
        }
        // Ensure this overlay spans full width so the text sits to the right of the spine (via reserveGutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Right-side cards + in-flow "textless" gap rows — only for spacing in View.
    @ViewBuilder
    private func CardsLayer(
        now: Date,
        plans: [ScheduledPlan],
        isEditing: Bool,
        startOfDay: Date,
        endDay: Date,
        minuteHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Spacer before the first plan
            if let first = plans.first {
                let lead = max(
                    0,
                    Int(first.startTime.timeIntervalSince(startOfDay) / 60)
                )
                let showFirstGapRow = (!isEditing && now < first.startTime)

                AnimHeightSpacer(
                    height: isEditing ? CGFloat(lead) * minuteHeight : 0,
                    animate: isEditing,
                    delay: 0,
                    duration: TimelineStyle.cardRepositionDuration
                )

                // Reserve space in View, but do NOT render visible text (overlay handles it)
                GapSpaceRow(show: showFirstGapRow)
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
                    let showBetweenGapRow =
                        (!isEditing && now >= prev.endTime
                            && now < sp.startTime)

                    // Spacer representing the time gap (Edit only)
                    AnimHeightSpacer(
                        height: isEditing ? CGFloat(gap) * minuteHeight : 0,
                        animate: isEditing,
                        delay: 0,
                        duration: TimelineStyle.cardRepositionDuration
                    )

                    // Reserve space in View, but do NOT render visible text (overlay handles it)
                    GapSpaceRow(show: showBetweenGapRow)
                }

                // The actual plan card
                TimelineCardOnlyRow(
                    sp: sp,
                    isFirst: i == 0,
                    isLast: i == plans.count - 1,
                    now: now,
                    isEditing: isEditing,
                    editMinuteHeight: minuteHeight,
                    reserveGutter: isEditing || (mode == .view)
                )
            }

            // Spacer after the last plan
            if let last = plans.last {
                let tail = max(
                    0,
                    Int(endDay.timeIntervalSince(last.endTime) / 60)
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

    /// In-flow spacing row with no visible text (keeps vertical rhythm in View).
    @ViewBuilder
    private func GapSpaceRow(show: Bool) -> some View {
        let rowHeight: CGFloat = 26  // match TimelineGapSpineRow
        Color.clear
            .frame(height: show ? rowHeight : 0)
            .animation(
                .easeInOut(duration: TimelineStyle.cardRepositionDuration),
                value: show
            )
            .accessibilityHidden(true)
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
