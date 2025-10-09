import SwiftData
import SwiftUI

enum TimelineGapKind { case between, beforeFirst }

struct TimelineGapRow: View {
    let minutesUntil: Int
    let showSpine: Bool
    let isEditing: Bool
    let kind: TimelineGapKind

    // Keep in sync with `TimelineSpineRow.leftColumnWidth` (dotDiameter + 16)
    private let leftColumnWidth: CGFloat = 46  // 30 + 16
    private let gapWidth: CGFloat = 12
    private let lineWidth: CGFloat = 2
    private let gutterAnimDuration: Double = 0.32

    @State private var currentGutter: CGFloat = 0
    private var separator: Color { Color(uiColor: .separator) }

    private var totalGutter: CGFloat { leftColumnWidth + gapWidth }
    private var keepGutterSpace: Bool { isEditing || showSpine }

    init(
        minutesUntil: Int,
        showSpine: Bool,
        isEditing: Bool,
        kind: TimelineGapKind = .between
    ) {
        self.minutesUntil = minutesUntil
        self.showSpine = showSpine
        self.isEditing = isEditing
        self.kind = kind
    }

    var body: some View {
        ZStack(alignment: .leading) {
            card
                .padding(.leading, currentGutter)
                .animation(
                    .easeInOut(duration: gutterAnimDuration),
                    value: currentGutter
                )

            spine
                .frame(width: leftColumnWidth, alignment: .center)
                .opacity(showSpine ? 1 : 0)
                .offset(x: showSpine ? 0 : -16)  // fade out to the RIGHT on hide
                .animation(
                    .easeInOut(duration: 0.22),
                    value: showSpine
                )
                .accessibilityHidden(!showSpine)
        }
        .onAppear {
            currentGutter = keepGutterSpace ? totalGutter : 0
        }
        .onChange(of: showSpine) { _ in
            withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                currentGutter = keepGutterSpace ? totalGutter : 0
            }
        }
        .onChange(of: isEditing) { _ in
            withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                currentGutter = keepGutterSpace ? totalGutter : 0
            }
        }
    }

    private var card: some View {
        let label =
            (kind == .beforeFirst) ? "until schedule starts" : "until next plan"
        return Text("\(TimeUtil.formatMinutes(minutesUntil)) \(label)")
            .font(.footnote.weight(.bold))
            .padding(.vertical, 10)
            .foregroundColor(.accentColor)
            .padding(.vertical, 6)
    }

    @ViewBuilder private var spine: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let cx = max(1, leftColumnWidth / 2)

            switch kind {
            case .between:
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    separator,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )

                let fadePrimary = LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .primary, location: 0.0),
                        .init(color: .primary.opacity(0), location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    fadePrimary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )

            case .beforeFirst:
                let fadeSeparatorIn = LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: separator.opacity(0), location: 0.0),
                        .init(color: separator, location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    fadeSeparatorIn,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// =====================================================
// MARK: - Decoupled Views (Card-only / Spine-only)
// =====================================================

/// Card-only rendering for a scheduled plan row (no spine drawing).
struct TimelineCardOnlyRow: View {
    // Inputs
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let now: Date
    let isEditing: Bool
    let editMinuteHeight: CGFloat
    /// If true, keeps the left gutter space equal to the spine column width so layout matches when spines are overlaid.
    let reserveGutter: Bool

    // VM
    @StateObject private var vm: TimelineSpineRowViewModel

    // Style & layout constants (keep in sync with TimelineSpineRow)
    private let dotDiameter: CGFloat = 30
    private var leftColumnWidth: CGFloat { dotDiameter + 16 }  // 46
    private let gapWidth: CGFloat = 12
    private let gutterAnimDuration: Double = 0.32

    private let viewModeHeight: CGFloat = 82

    // Anim state
    @State private var displayedProgress: Double = 0
    @State private var isCollapsing = false
    @State private var currentGutter: CGFloat = 0

    init(
        sp: ScheduledPlan,
        isFirst: Bool,
        isLast: Bool,
        now: Date,
        isEditing: Bool,
        editMinuteHeight: CGFloat,
        reserveGutter: Bool
    ) {
        self.sp = sp
        self.isFirst = isFirst
        self.isLast = isLast
        self.now = now
        self.isEditing = isEditing
        self.editMinuteHeight = editMinuteHeight
        self.reserveGutter = reserveGutter
        _vm = StateObject(wrappedValue: TimelineSpineRowViewModel(sp: sp))
    }

    // Derived
    private var start: Date { sp.startTime }
    private var end: Date { sp.endTime }
    private var status: TimelineSpineRowViewModel.Status { vm.status(now: now) }
    private var liveProgress: Double { vm.liveProgress(now: now) }
    private var planTint: Color { sp.plan?.tintColor ?? .accentColor }

    private var durationMinutes: Int { max(0, Int(sp.duration / 60)) }
    private var editExactHeight: CGFloat {
        CGFloat(durationMinutes) * editMinuteHeight
    }
    private var cardHeight: CGFloat {
        isEditing ? editExactHeight : viewModeHeight
    }

    private var nowTextColor: Color { planTint }
    private var nowBackground: some ShapeStyle { planTint.opacity(0.16) }
    private var nowBorder: Color { planTint.opacity(0.35) }

    private var keepGutterSpace: Bool { reserveGutter }
    private var totalGutter: CGFloat { leftColumnWidth + gapWidth }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(sp.plan?.title ?? "Untitled").font(.headline)

                Text(vm.timeRangeString())
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if status == .current {
                    ProgressView(value: displayedProgress)
                        .progressViewStyle(.linear)
                        .tint(planTint)
                        .animation(
                            isCollapsing ? nil : .linear(duration: 0.6),
                            value: displayedProgress
                        )
                        .blur(radius: isCollapsing ? 1.2 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)

            if status == .current {
                HStack(spacing: 4) { Text("Now") }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(nowTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(nowBackground, in: Capsule())
                    .overlay(Capsule().stroke(nowBorder, lineWidth: 1))
                    .shadow(color: planTint.opacity(0.25), radius: 3, y: 1)
                    .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(height: cardHeight, alignment: .top)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .opacity(status == .past ? 0.6 : 1)
        .padding(.vertical, isEditing ? 0 : 8)
        .padding(.leading, currentGutter)
        .animation(
            .easeInOut(duration: gutterAnimDuration),
            value: currentGutter
        )
        .animation(repositionAnimation, value: isEditing)
        .onAppear {
            currentGutter = keepGutterSpace ? totalGutter : 0
            displayedProgress = liveProgress
        }
        .onChange(of: liveProgress) { new in
            if isCollapsing {
                displayedProgress = new
            } else {
                withAnimation(.linear(duration: 0.6)) {
                    displayedProgress = new
                }
            }
        }
        .onChange(of: reserveGutter) { _ in
            isCollapsing = true
            withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                currentGutter = keepGutterSpace ? totalGutter : 0
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + gutterAnimDuration + 0.02
            ) {
                isCollapsing = false
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var repositionAnimation: Animation {
        isEditing
            ? .easeInOut(duration: 0.38)  // instant start on View→Edit
            : .easeInOut(duration: 0.28)
    }

    private var accessibilityText: Text {
        let title = Text(sp.plan?.title ?? "Untitled")
        let time = Text(
            "\(start.formatted(date: .omitted, time: .shortened)) to \(end.formatted(date: .omitted, time: .shortened))"
        )
        let state: Text = {
            switch status {
            case .past: return Text("Completed")
            case .current: return Text("In progress")
            case .upcoming: return Text("Scheduled")
            }
        }()
        return title + Text(". ") + state + Text(". ") + time
    }
}

/// Spine-only rendering for a scheduled plan row (no card surface).
// Replace ONLY TimelineSpineOnlyRow with this version.
// Goal: keep the spine visually continuous (no padding gaps) AND realign with cards.
// We achieve this by making each spine row TALLER by the same vertical padding the card rows use (8 top + 8 bottom),
// so cumulative heights match — but we draw the line across the ENTIRE row height (no visible breaks).

struct TimelineSpineOnlyRow: View {
    // Inputs
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let now: Date
    let showSpine: Bool
    let isEditing: Bool  // spines don't relocate; kept for API symmetry
    let editMinuteHeight: CGFloat

    // VM
    @StateObject private var vm: TimelineSpineRowViewModel

    // Style constants (keep in sync)
    private let dotDiameter: CGFloat = 30
    private var leftColumnWidth: CGFloat { dotDiameter + 16 }  // 46
    private let lineWidth: CGFloat = 2
    private let spineFadeDuration: Double = 0.22

    // Match the card’s view-mode vertical padding: 8 top + 8 bottom
    // (See TimelineCardOnlyRow: `.padding(.vertical, isEditing ? 0 : 8)`)
    private let cardVerticalPadView: CGFloat = 8
    private let viewModeHeight: CGFloat = 82

    // Keep spines at view-mode geometry (no edit relocation).
    // In VIEW mode we *add* the card padding into the actual row height so cumulative stacks match,
    // and we draw the spine through that extra space to keep it continuous.
    private var rowHeight: CGFloat {
        viewModeHeight + (cardVerticalPadView * 2)
    }

    // Derived
    private var status: TimelineSpineRowViewModel.Status { vm.status(now: now) }
    private var planTint: Color { sp.plan?.tintColor ?? .accentColor }
    private var separator: Color { Color(uiColor: .separator) }

    init(
        sp: ScheduledPlan,
        isFirst: Bool,
        isLast: Bool,
        now: Date,
        showSpine: Bool,
        isEditing: Bool,
        editMinuteHeight: CGFloat
    ) {
        self.sp = sp
        self.isFirst = isFirst
        self.isLast = isLast
        self.now = now
        self.showSpine = showSpine
        self.isEditing = isEditing
        self.editMinuteHeight = editMinuteHeight
        _vm = StateObject(wrappedValue: TimelineSpineRowViewModel(sp: sp))
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let h = geo.size.height
                let cx = max(1, leftColumnWidth / 2)
                let cy = h / 2
                let px: CGFloat = 1 / UIScreen.main.scale

                let showDot = status != .past
                let topEndY: CGFloat = showDot ? (cy - dotDiameter / 2) : cy
                let bottomStartY: CGFloat =
                    showDot ? (cy + dotDiameter / 2) : cy

                // TOP SEGMENT
                switch status {
                case .past:
                    if isFirst {
                        let g = LinearGradient(
                            colors: [Color.primary.opacity(0), .primary],
                            startPoint: .top,
                            endPoint: .center
                        )
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else {
                        vline(
                            cx: cx,
                            fromY: 0,
                            toY: topEndY,
                            style: Color.primary
                        )
                    }
                case .current:
                    if isFirst {
                        let g = LinearGradient(
                            colors: [Color.primary.opacity(0), planTint],
                            startPoint: .top,
                            endPoint: .center
                        )
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else {
                        vline(
                            cx: cx,
                            fromY: 0,
                            toY: topEndY,
                            style: LinearGradient(
                                colors: [.primary, planTint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                case .upcoming:
                    vline(cx: cx, fromY: 0, toY: topEndY, style: separator)
                }

                // BOTTOM SEGMENT
                switch status {
                case .past:
                    if isLast {
                        let g = LinearGradient(
                            colors: [.primary, Color.primary.opacity(0)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        vline(
                            cx: cx,
                            fromY: bottomStartY - px,
                            toY: h + px,
                            style: g
                        )
                    } else {
                        vline(
                            cx: cx,
                            fromY: bottomStartY - px,
                            toY: h + px,
                            style: Color.primary
                        )
                    }
                case .current:
                    if !isLast {
                        let g = LinearGradient(
                            colors: [planTint, separator],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        vline(
                            cx: cx,
                            fromY: bottomStartY - px,
                            toY: h + px,
                            style: g
                        )
                    }
                case .upcoming:
                    if !isLast {
                        vline(
                            cx: cx,
                            fromY: bottomStartY,
                            toY: h + px,
                            style: separator
                        )
                    }
                }

                // DOT
                if showDot {
                    RoundedRectangle(
                        cornerRadius: dotDiameter * 0.40,
                        style: .continuous
                    )
                    .fill(status == .current ? planTint : separator)
                    .frame(width: dotDiameter, height: dotDiameter)
                    .overlay {
                        let side = dotDiameter - 2 * (dotDiameter * 0.08)
                        Text(sp.plan?.emoji ?? "🧩")
                            .font(.system(size: dotDiameter * 0.48))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(
                                width: side,
                                height: side,
                                alignment: .center
                            )
                            .offset(y: -0.5)
                            .accessibilityHidden(true)
                    }
                    .shadow(radius: status == .current ? 2 : 0, y: 1)
                    .position(x: cx, y: cy)
                    .drawingGroup()
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(height: rowHeight)  // <- extra 16pt is part of geometry
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(width: leftColumnWidth, alignment: .center)
        .opacity(showSpine ? 1 : 0)
        .offset(x: showSpine ? 0 : -16)  // fade/slide out RIGHT on hide
        .animation(.easeInOut(duration: spineFadeDuration), value: showSpine)
    }

    private func vline<S: ShapeStyle>(
        cx: CGFloat,
        fromY: CGFloat,
        toY: CGFloat,
        style: S
    ) -> some View {
        Path { p in
            p.move(to: CGPoint(x: cx, y: fromY))
            p.addLine(to: CGPoint(x: cx, y: toY))
        }
        .stroke(style, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    }
}

/// Card-only view for the gap label row.
struct TimelineGapCardRow: View {
    let minutesUntil: Int
    let isEditing: Bool
    let reserveGutter: Bool

    private let leftColumnWidth: CGFloat = 46  // 30 + 16
    private let gapWidth: CGFloat = 12
    private let gutterAnimDuration: Double = 0.32

    @State private var currentGutter: CGFloat = 0
    private var totalGutter: CGFloat { leftColumnWidth + gapWidth }

    var body: some View {
        Text("\(TimeUtil.formatMinutes(minutesUntil)) until next plan")
            .font(.footnote.weight(.bold))
            .padding(.vertical, 10)
            .foregroundColor(.accentColor)
            .padding(.vertical, 6)
            .padding(.leading, currentGutter)
            .animation(
                .easeInOut(duration: gutterAnimDuration),
                value: currentGutter
            )
            .onAppear { currentGutter = reserveGutter ? totalGutter : 0 }
            .onChange(of: reserveGutter) { _ in
                withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                    currentGutter = reserveGutter ? totalGutter : 0
                }
            }
    }
}

/// Spine-only view for the gap row (visual continuation of the spine).
struct TimelineGapSpineRow: View {
    enum Kind { case between, beforeFirst }
    let kind: Kind

    private let leftColumnWidth: CGFloat = 46
    private let lineWidth: CGFloat = 2
    private var separator: Color { Color(uiColor: .separator) }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let cx = max(1, leftColumnWidth / 2)

            switch kind {
            case .between:
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    separator,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )

                let fadePrimary = LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .primary, location: 0.0),
                        .init(color: .primary.opacity(0), location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    fadePrimary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )

            case .beforeFirst:
                let fadeSeparatorIn = LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: separator.opacity(0), location: 0.0),
                        .init(color: separator, location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    fadeSeparatorIn,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 26)  // approximate natural height of the label row
        .frame(width: leftColumnWidth, alignment: .center)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
