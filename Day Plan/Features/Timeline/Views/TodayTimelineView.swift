import SwiftData
import SwiftUI
import UIKit

/// Renders today's timeline for a given template ID.
/// View mode shows the classic spine; Edit mode overlays an hour grid and renders
/// cards at exact time heights, with time-accurate spacing between items.
struct TodayTimelineView: View {
    let templateID: UUID

    // Live-updating plans for this template, sorted by start time.
    @Query private var scheduled: [ScheduledPlan]

    private enum Mode: String, CaseIterable {
        case view = "View"
        case edit = "Edit"
    }
    private enum GutterMode: String, CaseIterable {
        case auto = "Auto"
        case show = "Show"
        case hide = "Hide"
    }

    @State private var mode: Mode = .view
    @State private var gutterMode: GutterMode = .auto

    private let tick: TimeInterval = 1
    private let editMinuteHeight: CGFloat = 1.4

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
            let showSpine = spineVisible(now: now, plans: plans)

            VStack(alignment: .leading, spacing: 12) {
                header(now: now)

                ZStack(alignment: .topLeading) {
                    if mode == .edit {
                        HoursGridLayer(
                            minuteHeight: editMinuteHeight,
                            start: startOfDay(now)
                        )
                        .frame(
                            height: HoursGridLayer.requiredHeight(
                                minuteHeight: editMinuteHeight))
                    }

                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            // Spacer from 00:00 → first plan start (Edit) or the "until next plan" row (View).
                            if mode == .edit, let first = plans.first {
                                let lead = max(
                                    0,
                                    Int(
                                        first.startTime.timeIntervalSince(
                                            startOfDay(now)) / 60))
                                if lead > 0 {
                                    Color.clear.frame(
                                        height: CGFloat(lead) * editMinuteHeight
                                    )
                                }
                            } else if let first = plans.first,
                                now < first.startTime
                            {
                                let minsLeft = max(
                                    0,
                                    Int(
                                        first.startTime.timeIntervalSince(now)
                                            / 60))
                                TimelineGapRow(
                                    minutesUntil: minsLeft,
                                    showSpine: showSpine,
                                    isEditing: (mode == .edit),
                                    kind: .beforeFirst
                                )
                                .transition(.opacity)
                            }

                            ForEach(Array(plans.enumerated()), id: \.element.id)
                            { i, sp in
                                // Spacer between items in Edit mode based on actual time deltas.
                                if mode == .edit, i > 0 {
                                    let prev = plans[i - 1]
                                    let gap = max(
                                        0,
                                        Int(
                                            sp.startTime.timeIntervalSince(
                                                prev.endTime) / 60))
                                    if gap > 0 {
                                        Color.clear.frame(
                                            height: CGFloat(gap)
                                                * editMinuteHeight)
                                    }
                                }

                                TimelineSpineRow(
                                    sp: sp,
                                    isFirst: i == 0,
                                    isLast: i == plans.count - 1,
                                    dayStart: startOfDay(now),
                                    now: now,
                                    showSpine: showSpine,
                                    isEditing: (mode == .edit),
                                    editMinuteHeight: editMinuteHeight
                                )
                            }

                            // Optional tail to 24:00 in Edit mode to complete the 24h stack.
                            if mode == .edit, let last = plans.last {
                                let tail = max(
                                    0,
                                    Int(
                                        endOfDay(now).timeIntervalSince(
                                            last.endTime) / 60))
                                if tail > 0 {
                                    Color.clear.frame(
                                        height: CGFloat(tail) * editMinuteHeight
                                    )
                                }
                            }
                        }
                        .padding(
                            .top, mode == .edit ? HoursGridLayer.topInset : 0
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
    private func header(now: Date) -> some View {
        HStack(spacing: 12) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            Picker("", selection: $gutterMode) {
                ForEach(GutterMode.allCases, id: \.self) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .disabled(mode == .edit)
            .opacity(mode == .edit ? 0.5 : 1)
        }
    }

    // MARK: - Policy

    private func spineVisible(now: Date, plans: [ScheduledPlan]) -> Bool {
        if mode == .edit { return false }
        switch gutterMode {
        case .show: return true
        case .hide: return false
        case .auto:
            guard let lastEnd = plans.map(\.endTime).max() else { return false }
            return now <= lastEnd
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

// MARK: - Hours Grid (Edit mode)

/// Hour grid with flush-left labels/ticks and top inset = half lineHeight,
/// so 00:00 isn't clipped and 24:00 remains visible when sized via `requiredHeight`.
private struct HoursGridLayer: View {
    let minuteHeight: CGFloat
    let start: Date

    static var topInset: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2).lineHeight / 2
    }

    static func requiredHeight(minuteHeight: CGFloat) -> CGFloat {
        let lh = UIFont.preferredFont(forTextStyle: .caption2).lineHeight
        return (1440 * minuteHeight) + lh
    }

    private var hourCount: Int { 25 }  // 0…24 inclusive

    private let columnWidth: CGFloat = 56
    private let labelWidth: CGFloat = 34
    private let labelTickGap: CGFloat = 6
    private let majorTickWidth: CGFloat = 12
    private let minorTickWidth: CGFloat = 8

    private var labelLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2).lineHeight
    }
    private var topInsetLocal: CGFloat { Self.topInset }

    // Centers chosen so the left edge sits at x = 0.
    private var majorRowCenterX: CGFloat {
        (labelWidth + labelTickGap + majorTickWidth) / 2
    }
    private var minorTickCenterX: CGFloat {
        labelWidth + labelTickGap + (minorTickWidth / 2)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour labels + major ticks
            ForEach(0..<hourCount, id: \.self) { h in
                let y = topInsetLocal + CGFloat(h) * 60 * minuteHeight
                HStack(spacing: labelTickGap) {
                    Text(formattedHour(h))
                        .font(.caption2)
                        .frame(width: labelWidth, alignment: .trailing)
                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(width: majorTickWidth, height: 1)
                        .opacity(0.8)
                }
                .position(x: majorRowCenterX, y: y)
            }

            // Minor ticks every 15 minutes
            ForEach(0..<((hourCount - 1) * 3), id: \.self) { i in
                let y = topInsetLocal + CGFloat(i + 1) * 15 * minuteHeight
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.35))
                    .frame(width: minorTickWidth, height: 1)
                    .position(x: minorTickCenterX, y: y)
            }
        }
        .frame(width: columnWidth, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func formattedHour(_ offset: Int) -> String {
        let date =
            Calendar.current.date(byAdding: .hour, value: offset, to: start)
            ?? start
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened))
    }
}
