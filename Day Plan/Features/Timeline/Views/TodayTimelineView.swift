import SwiftData
import SwiftUI

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

    var body: some View {
        Group {
            if templateResults.first != nil {
                let window = vm.dayWindow()

                VStack(spacing: 10) {
                    headerControls

                    TimelineView(.periodic(from: .now, by: tick)) { context in
                        let plans = scheduled
                        let now = vm.anchoredNow(
                            context.date, dayStart: window.start,
                            dayEnd: window.end
                        )

                        // Compute view-mode "auto" behavior
                        let projectedEnds = plans.map {
                            vm.projectedEnd(for: $0, in: window)
                        }
                        let lastEndToday = projectedEnds.max() ?? window.start
                        let dayComplete = now >= lastEndToday

                        let showSpineInViewMode =
                            (gutterMode == .show)
                            || (gutterMode == .auto && !dayComplete)

                        // Force spine hidden in edit mode; show hours grid instead.
                        let showSpine =
                            (mode == .view) ? showSpineInViewMode : false
                        let showHoursGrid = (mode == .edit)

                        if plans.isEmpty {
                            emptyState
                        } else {
                            // We layer a single continuous HoursGrid behind the list when editing.
                            ScrollView {
                                ZStack(alignment: .topLeading) {
                                    if showHoursGrid {
                                        HoursGridLayer(
                                            minuteHeight: editMinuteHeight,
                                            start: window.start
                                        )
                                        // 24h track height; allows scrolling the whole day
                                        .frame(height: 1440 * editMinuteHeight)
                                        .transition(
                                            .opacity.combined(with: .scale))
                                    }

                                    // The list sits above. In edit mode, cards animate their
                                    // minHeight toward real-time height; we keep the same list structure.
                                    LazyVStack(alignment: .leading, spacing: 0)
                                    {
                                        // BEFORE FIRST PLAN gap
                                        if let first = plans.first,
                                            now < first.startTime
                                        {
                                            let minsLeft = max(
                                                0,
                                                Int(
                                                    first.startTime
                                                        .timeIntervalSince(now)
                                                        / 60)
                                            )
                                            TimelineGapRow(
                                                minutesUntil: minsLeft,
                                                showSpine: showSpine,
                                                kind: .beforeFirst
                                            )
                                            .transition(.opacity)
                                        }

                                        // PLANS
                                        ForEach(plans.indices, id: \.self) {
                                            i in
                                            let sp = plans[i]

                                            // Neighbor color hints for vertical spine blending.
                                            let topFrom: Color? =
                                                (i > 0)
                                                ? vm.outputColor(
                                                    for: plans[i - 1], now: now)
                                                : nil
                                            let bottomTo: Color? =
                                                (i < plans.count - 1)
                                                ? vm.outputColor(
                                                    for: plans[i + 1], now: now)
                                                : nil

                                            TimelineSpineRow(
                                                sp: sp,
                                                isFirst: i == 0,
                                                isLast: i == plans.count - 1,
                                                // legacy param kept; unused in row
                                                dayStart: window.start,
                                                now: now,
                                                showSpine: showSpine,
                                                topFromColor: topFrom,
                                                bottomToColor: bottomTo,
                                                // NEW: visual-only edit mode sizing
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
                            .animation(.easeInOut(duration: 0.28), value: mode)
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

            if mode == .view {
                Picker("Spine", selection: $gutterMode) {
                    ForEach(GutterMode.allCases, id: \.self) {
                        Text($0.rawValue.capitalized)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                .transition(.opacity.combined(with: .scale))
            }

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
/// - Drawn once (not per row) to avoid seams and keep alignment stable.
/// - For this first step it's visual-only: we don't handle gestures yet.
private struct HoursGridLayer: View {
    let minuteHeight: CGFloat
    let start: Date

    private var hourCount: Int { 25 }  // 0...24 inclusive for the bottom label

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Column background (subtle to contrast with cards)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .frame(width: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            Color(uiColor: .separator).opacity(0.3),
                            lineWidth: 1)
                )

            // Tick marks + labels
            ForEach(0..<hourCount, id: \.self) { h in
                let y = CGFloat(h) * 60 * minuteHeight
                HStack(spacing: 6) {
                    Text(formattedHour(h))
                        .font(.caption2)
                        .frame(width: 34, alignment: .trailing)

                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(width: 12, height: 1)
                        .opacity(0.8)
                }
                .position(x: 28, y: y)  // center within 56pt column
            }

            // Minor ticks (every 15 min)
            ForEach(0..<((hourCount - 1) * 3), id: \.self) { i in
                let y = CGFloat(i + 1) * 15 * minuteHeight
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.35))
                    .frame(width: 8, height: 1)
                    .position(x: 30, y: y)
            }
        }
        .padding(.leading, 8)  // slight breathing room from screen edge
        .allowsHitTesting(false)  // visual-only for now
    }

    private func formattedHour(_ h: Int) -> String {
        let hour = h % 24
        let comps = DateComponents(hour: hour, minute: 0)
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
