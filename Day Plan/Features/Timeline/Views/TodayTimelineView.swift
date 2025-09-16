import SwiftData
import SwiftUI
import UIKit

/// Renders today's timeline for a given template ID.
/// Uses live `@Query` for the template and its scheduled plans to avoid
/// race conditions on first render (before a ModelContext is attached).
///
/// Two modes:
/// - View mode: current read-only timeline with a vertical spine.
/// - Edit mode: the spine hides and an hours column appears; cards visually
///   grow to "real-time" heights (purely visual for now; no state changes).
struct TodayTimelineView: View {
    let templateID: UUID

    @StateObject private var vm: TodayTimelineViewModel

    // Live SwiftData queries. These are parameterized in init using the templateID.
    @Query private var templateResults: [DayTemplate]
    @Query private var scheduled: [ScheduledPlan]

    // MARK: - UI mode
    enum Mode: String, CaseIterable {
        case view = "View"
        case edit = "Edit"
    }
    @State private var mode: Mode = .view

    /// Spine visibility policy used only in view mode:
    /// - .auto: show until all items are finished (then animate out)
    /// - .show: always show
    /// - .hide: always hide
    private enum GutterMode: String, CaseIterable { case auto, show, hide }
    @State private var gutterMode: GutterMode = .auto

    /// TimelineView tick cadence. 1s feels live without being heavy.
    private let tick: TimeInterval = 1

    /// Visual scale for edit mode (px per minute). Adjust to taste.
    /// Cards expand toward `durationMinutes * editMinuteHeight`.
    private let editMinuteHeight: CGFloat = 1.4

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

    // Unified spine policy (derived from both pickers)
    private enum SpinePolicy { case always, autoUntilComplete, hidden }

    private func spinePolicy(for mode: Mode, gutterMode: GutterMode)
        -> SpinePolicy
    {
        // Edit mode always hides the spine; View mode uses the gutter picker.
        if mode == .edit { return .hidden }
        switch gutterMode {
        case .show: return .always
        case .hide: return .hidden
        case .auto: return .autoUntilComplete
        }
    }

    private func shouldShowSpine(
        now: Date,
        plans: [ScheduledPlan],
        window: DayWindow
    ) -> Bool {
        switch spinePolicy(for: mode, gutterMode: gutterMode) {
        case .always: return true
        case .hidden: return false
        case .autoUntilComplete:
            let lastEndToday =
                plans
                .map { vm.projectedEnd(for: $0, in: window) }  // now matches the expected type
                .max() ?? window.start
            return now < lastEndToday
        }
    }

    var body: some View {
        Group {
            if templateResults.first != nil {
                let window = vm.dayWindow()

                VStack(spacing: 10) {
                    headerControls

                    TimelineView(.periodic(from: .now, by: tick)) { context in
                        let window = vm.dayWindow()  // compute here so types are crystal-clear
                        let plans = scheduled
                        let now = vm.anchoredNow(
                            context.date, dayStart: window.start,
                            dayEnd: window.end)

                        let showSpine = shouldShowSpine(
                            now: now, plans: plans, window: window)
                        let showHoursGrid = (mode == .edit)

                        Group {
                            if plans.isEmpty {
                                emptyState
                            } else {
                                ScrollView {
                                    ZStack(alignment: .topLeading) {
                                        if showHoursGrid {
                                            HoursGridLayer(
                                                minuteHeight: editMinuteHeight,
                                                start: window.start
                                            )
                                            .frame(
                                                height: 1440 * editMinuteHeight
                                            )
                                            .transition(
                                                .opacity.combined(with: .scale))
                                        }

                                        LazyVStack(
                                            alignment: .leading, spacing: 0
                                        ) {
                                            if let first = plans.first,
                                                now < first.startTime
                                            {
                                                let minsLeft = max(
                                                    0,
                                                    Int(
                                                        first.startTime
                                                            .timeIntervalSince(
                                                                now) / 60))
                                                TimelineGapRow(
                                                    minutesUntil: minsLeft,
                                                    showSpine: showSpine,
                                                    isEditing: (mode == .edit),
                                                    kind: .beforeFirst
                                                )

                                                .transition(.opacity)
                                            }

                                            ForEach(plans.indices, id: \.self) {
                                                i in
                                                let sp = plans[i]
                                                let topFrom: Color? =
                                                    (i > 0)
                                                    ? vm.outputColor(
                                                        for: plans[i - 1],
                                                        now: now) : nil
                                                let bottomTo: Color? =
                                                    (i < plans.count - 1)
                                                    ? vm.outputColor(
                                                        for: plans[i + 1],
                                                        now: now) : nil

                                                TimelineSpineRow(
                                                    sp: sp,
                                                    isFirst: i == 0,
                                                    isLast: i == plans.count
                                                        - 1,
                                                    dayStart: window.start,  // legacy param kept; unused in row
                                                    now: now,
                                                    showSpine: showSpine,
                                                    topFromColor: topFrom,
                                                    bottomToColor: bottomTo,
                                                    isEditing: (mode == .edit),
                                                    editMinuteHeight:
                                                        editMinuteHeight
                                                )
                                                .animation(
                                                    .easeInOut(duration: 0.28),
                                                    value: mode)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                                .scrollIndicators(.never)
                                .animation(
                                    .easeInOut(duration: 0.28), value: mode)
                            }
                        }
                    }

                }
            } else {
                ContentUnavailableView("Loading…", systemImage: "clock")
                    .transition(.opacity)
            }
        }
        .id(templateID)  // keep scroll state per template
    }

    // MARK: - Controls

    @ViewBuilder
    private var headerControls: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            Picker("Spine", selection: $gutterMode) {
                ForEach(GutterMode.allCases, id: \.self) {
                    Text($0.rawValue.capitalized)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .transition(.opacity.combined(with: .scale))

            Spacer()
        }
        .padding(.horizontal)
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

/// A single, continuous 24-hour column of ticks and hour labels.
/// Uses a top inset = half of caption2 lineHeight so 0:00 isn't clipped,
/// and increases total height by one full line to keep 24:00 visible.
private struct HoursGridLayer: View {
    let minuteHeight: CGFloat
    let start: Date

    // Expose the exact height the parent should use.
    static func requiredHeight(minuteHeight: CGFloat) -> CGFloat {
        let lh = UIFont.preferredFont(forTextStyle: .caption2).lineHeight
        return (1440 * minuteHeight) + lh
    }

    private var hourCount: Int { 25 }  // 0…24 inclusive

    // Layout constants
    private let columnWidth: CGFloat = 56
    private let labelWidth: CGFloat = 34
    private let labelTickGap: CGFloat = 6
    private let majorTickWidth: CGFloat = 12
    private let minorTickWidth: CGFloat = 8

    // Typography metrics
    private var labelLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2).lineHeight
    }
    private var topInset: CGFloat { labelLineHeight / 2 }

    // Centers to keep the left edge flush at x = 0
    private var majorRowCenterX: CGFloat {
        (labelWidth + labelTickGap + majorTickWidth) / 2
    }
    private var minorTickCenterX: CGFloat {
        labelWidth + labelTickGap + (minorTickWidth / 2)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Major ticks + labels (every hour)
            ForEach(0..<hourCount, id: \.self) { h in
                let y = topInset + CGFloat(h) * 60 * minuteHeight
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

            // Minor ticks (every 15 minutes)
            ForEach(0..<((hourCount - 1) * 3), id: \.self) { i in
                let y = topInset + CGFloat(i + 1) * 15 * minuteHeight
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
        let cal = Calendar.current
        let date = cal.date(byAdding: .hour, value: offset, to: start) ?? start
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened))
    }
}
