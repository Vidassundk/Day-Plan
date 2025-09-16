import SwiftData
import SwiftUI

/// A single timeline row: vertical spine + dot + plan card.
/// - Uses `TimelineSpineRowViewModel` for status/progress calculations.
/// - In edit mode, cards render at exact time height for accurate alignment against the hour grid.
struct TimelineSpineRow: View {
    // MARK: Inputs from parent
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let now: Date
    let showSpine: Bool

    /// Neighbor color hints (for blending at junctions).
    let topFromColor: Color?
    let bottomToColor: Color?

    /// If a neighbor is ACTIVE, use a single-color hinge at the junction.
    let topJunctionMid: Color?
    let bottomJunctionMid: Color?

    /// Visual-only edit mode: affects card height and spine visibility (spine hidden by parent).
    let isEditing: Bool
    /// Visual scale for edit mode (px per minute). Cards stretch to duration × scale.
    let editMinuteHeight: CGFloat

    // MARK: VM
    @StateObject private var vm: TimelineSpineRowViewModel

    // MARK: Init
    init(
        sp: ScheduledPlan,
        isFirst: Bool,
        isLast: Bool,
        dayStart: Date,  // retained for call-site compatibility
        now: Date,
        showSpine: Bool = true,
        topFromColor: Color? = nil,
        bottomToColor: Color? = nil,
        topJunctionMid: Color? = nil,
        bottomJunctionMid: Color? = nil,
        isEditing: Bool = false,
        editMinuteHeight: CGFloat = 1.4
    ) {
        self.sp = sp
        self.isFirst = isFirst
        self.isLast = isLast
        self.now = now
        self.showSpine = showSpine
        self.topFromColor = topFromColor
        self.bottomToColor = bottomToColor
        self.topJunctionMid = topJunctionMid
        self.bottomJunctionMid = bottomJunctionMid
        self.isEditing = isEditing
        self.editMinuteHeight = editMinuteHeight
        _vm = StateObject(wrappedValue: TimelineSpineRowViewModel(sp: sp))
    }

    // MARK: Style knobs
    private enum DotStyle { case circle, squircle }
    private let dotStyle: DotStyle = .squircle
    private var dotCornerRadius: CGFloat { dotDiameter * 0.40 }

    private enum NowTagStyle { case subtleTint, solidTint }
    private let nowTagStyle: NowTagStyle = .subtleTint

    private let gapWidth: CGFloat = 12
    private let lineWidth: CGFloat = 2
    private let gutterAnimDuration: Double = 0.32

    // Dot sizing
    private let dotDiameter: CGFloat = 30
    private var dotEmojiScale: CGFloat { 0.48 }
    private var dotContentInset: CGFloat { dotDiameter * 0.08 }
    private var dotEmojiFont: Font {
        .system(size: dotDiameter * dotEmojiScale)
    }
    private let emojiBaselineNudge: CGFloat = -0.5

    private var leftColumnWidth: CGFloat { dotDiameter + 16 }

    // Reserve gutter in Edit mode to keep horizontal card width stable while the spine hides.
    private var totalGutter: CGFloat { leftColumnWidth + gapWidth }
    private var keepGutterSpace: Bool { isEditing || showSpine }

    // MARK: Card size bands (view mode “pleasant” heights)
    private enum CardSizeBand: Int, CaseIterable { case xs, s, m, l, xl }
    private func band(for minutes: Int) -> CardSizeBand {
        switch minutes {
        case ..<31: return .xs
        case ..<61: return .s
        case ..<121: return .m
        case ..<181: return .l
        default: return .xl
        }
    }
    private func minHeight(for band: CardSizeBand) -> CGFloat {
        switch band {
        case .xs: return 56
        case .s: return 72
        case .m: return 92
        case .l: return 116
        case .xl: return 140
        }
    }

    // MARK: Derived (via VM + local mapping)
    private var start: Date { sp.startTime }
    private var end: Date { sp.endTime }
    private var status: TimelineSpineRowViewModel.Status { vm.status(now: now) }
    private var liveProgress: Double { vm.liveProgress(now: now) }

    private var durationMinutes: Int { max(0, Int(sp.duration / 60)) }
    private var sizeBand: CardSizeBand { band(for: durationMinutes) }
    private var bandedMinHeight: CGFloat { minHeight(for: sizeBand) }

    /// Exact visual height for Edit; banded face height for View.
    private var editExactHeight: CGFloat {
        CGFloat(durationMinutes) * editMinuteHeight
    }
    private var cardHeight: CGFloat {
        isEditing ? editExactHeight : bandedMinHeight
    }

    // MARK: Anim state
    @State private var displayedProgress: Double = 0
    @State private var isCollapsing = false
    @State private var currentGutter: CGFloat = 0

    // MARK: Colors
    private var separator: Color { Color(uiColor: .separator) }
    private var planTint: Color { sp.plan?.tintColor ?? .accentColor }

    private var nowTextColor: Color {
        switch nowTagStyle {
        case .subtleTint: return planTint
        case .solidTint: return .white
        }
    }
    private var nowBackground: some ShapeStyle {
        switch nowTagStyle {
        case .subtleTint: return planTint.opacity(0.16)
        case .solidTint: return planTint
        }
    }
    private var nowBorder: Color {
        switch nowTagStyle {
        case .subtleTint: return planTint.opacity(0.35)
        case .solidTint: return planTint
        }
    }

    private var showDot: Bool { status != .past }
    private var dotFill: Color {
        switch status {
        case .current: return planTint
        case .upcoming, .past: return separator
        }
    }

    // MARK: Body
    var body: some View {
        ZStack(alignment: .leading) {
            card
                .padding(.leading, currentGutter)
                .animation(
                    .easeInOut(duration: gutterAnimDuration),
                    value: currentGutter)

            spine
                .frame(width: leftColumnWidth, alignment: .center)
                .opacity(showSpine ? 1 : 0)
                .offset(x: showSpine ? 0 : -8)
                .animation(
                    .easeInOut(duration: gutterAnimDuration), value: showSpine
                )
                .accessibilityHidden(!showSpine)
        }
        .animation(.easeInOut(duration: 0.28), value: isEditing)  // height transition
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
        .onChange(of: showSpine) { _ in
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
        .onChange(of: isEditing) { _ in
            withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                currentGutter = keepGutterSpace ? totalGutter : 0
            }
        }
    }

    // MARK: Pieces

    private var nowTag: some View {
        HStack(spacing: 4) { Text("Now") }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(nowTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(nowBackground, in: Capsule())
            .overlay(Capsule().stroke(nowBorder, lineWidth: 1))
            .shadow(
                color: nowTagStyle == .solidTint
                    ? planTint.opacity(0.25) : .clear, radius: 3, y: 1
            )
            .accessibilityHidden(true)
    }

    /// Card surface. In edit mode, content is top-aligned inside an exact-height block.
    private var card: some View {
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

            if status == .current { nowTag }
        }
        .padding(12)
        .frame(height: cardHeight, alignment: .top)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .opacity(status == .past ? 0.6 : 1)
        .padding(.vertical, isEditing ? 0 : 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// The vertical line + central dot column (hidden by parent in edit mode).
    private var spine: some View {
        ZStack {
            GeometryReader { geo in
                let h = geo.size.height
                let cx = max(1, geo.size.width / 2)
                let cy = h / 2
                let px: CGFloat = 1 / UIScreen.main.scale

                let topEndY: CGFloat = showDot ? (cy - dotDiameter / 2) : cy
                let bottomStartY: CGFloat =
                    showDot ? (cy + dotDiameter / 2) : cy

                // --- TOP SEGMENT ---
                switch status {
                case .past:
                    if isFirst {
                        let g = LinearGradient(
                            colors: [Color.primary.opacity(0), .primary],
                            startPoint: .top, endPoint: .center)
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else {
                        vline(
                            cx: cx, fromY: 0, toY: topEndY, style: Color.primary
                        )
                    }
                case .current:
                    if isFirst {
                        let g = LinearGradient(
                            colors: [Color.primary.opacity(0), planTint],
                            startPoint: .top, endPoint: .center)
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else if let mid = topJunctionMid {
                        let g = LinearGradient(
                            colors: [mid, planTint], startPoint: .top,
                            endPoint: .bottom)
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else {
                        let from = topFromColor ?? .primary
                        let neighborIsTint =
                            !(from == .primary || from == separator)
                        let startPt: UnitPoint =
                            neighborIsTint ? UnitPoint(x: 0.5, y: -1.0) : .top
                        let endPt: UnitPoint =
                            neighborIsTint ? .bottom : .center
                        let g = LinearGradient(
                            colors: [from, planTint], startPoint: startPt,
                            endPoint: endPt)
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    }
                case .upcoming:
                    vline(cx: cx, fromY: 0, toY: topEndY, style: separator)
                }

                // --- BOTTOM SEGMENT ---
                switch status {
                case .past:
                    if isLast {
                        let g = LinearGradient(
                            colors: [.primary, Color.primary.opacity(0)],
                            startPoint: .center, endPoint: .bottom)
                        vline(
                            cx: cx, fromY: bottomStartY - px, toY: h + px,
                            style: g)
                    } else {
                        vline(
                            cx: cx, fromY: bottomStartY - px, toY: h + px,
                            style: Color.primary)
                    }
                case .current:
                    if !isLast {
                        if let mid = bottomJunctionMid {
                            let g = LinearGradient(
                                colors: [planTint, mid], startPoint: .top,
                                endPoint: .bottom)
                            vline(
                                cx: cx, fromY: bottomStartY - px, toY: h + px,
                                style: g)
                        } else {
                            let target = bottomToColor ?? separator
                            let neighborIsTint =
                                !(target == .primary || target == separator)
                            let startPt: UnitPoint =
                                neighborIsTint ? .top : .center
                            let endPt: UnitPoint =
                                neighborIsTint
                                ? UnitPoint(x: 0.5, y: 2.0) : .bottom
                            let g = LinearGradient(
                                colors: [planTint, target], startPoint: startPt,
                                endPoint: endPt)
                            vline(
                                cx: cx, fromY: bottomStartY - px, toY: h + px,
                                style: g)
                        }
                    }
                case .upcoming:
                    if !isLast {
                        vline(
                            cx: cx, fromY: bottomStartY, toY: h + px,
                            style: separator)
                    }
                }

                // --- BIG DOT WITH EMOJI ---
                if showDot {
                    Group {
                        switch dotStyle {
                        case .circle:
                            Circle()
                                .fill(dotFill)
                                .frame(width: dotDiameter, height: dotDiameter)
                                .overlay(
                                    Circle().stroke(
                                        Color(uiColor: .systemBackground)
                                            .opacity(0.9), lineWidth: 2)
                                )
                                .overlay {
                                    let side = dotDiameter - 2 * dotContentInset
                                    Text(sp.plan?.emoji ?? "🧩")
                                        .font(dotEmojiFont)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .frame(
                                            width: side, height: side,
                                            alignment: .center
                                        )
                                        .offset(y: emojiBaselineNudge)
                                        .accessibilityHidden(true)
                                }
                                .shadow(
                                    radius: status == .current ? 2 : 0, y: 1)
                        case .squircle:
                            RoundedRectangle(
                                cornerRadius: dotCornerRadius,
                                style: .continuous
                            )
                            .fill(dotFill)
                            .frame(width: dotDiameter, height: dotDiameter)
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: dotCornerRadius,
                                    style: .continuous
                                )
                                .stroke(
                                    Color(uiColor: .systemBackground).opacity(
                                        0.9), lineWidth: 0)
                            )
                            .overlay {
                                let side = dotDiameter - 2 * dotContentInset
                                Text(sp.plan?.emoji ?? "🧩")
                                    .font(dotEmojiFont)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(
                                        width: side, height: side,
                                        alignment: .center
                                    )
                                    .offset(y: emojiBaselineNudge)
                                    .accessibilityHidden(true)
                            }
                            .shadow(radius: status == .current ? 2 : 0, y: 1)
                        }
                    }
                    .position(x: cx, y: cy)
                    .drawingGroup()
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: Helpers

    private func vline<S: ShapeStyle>(
        cx: CGFloat, fromY: CGFloat, toY: CGFloat, style: S
    ) -> some View {
        Path { p in
            p.move(to: CGPoint(x: cx, y: fromY))
            p.addLine(to: CGPoint(x: cx, y: toY))
        }
        .stroke(style, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
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

// MARK: - Gaps between items / before the first item

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
        minutesUntil: Int, showSpine: Bool, isEditing: Bool,
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
                    value: currentGutter)

            spine
                .frame(width: leftColumnWidth, alignment: .center)
                .opacity(showSpine ? 1 : 0)
                .offset(x: showSpine ? 0 : -8)
                .animation(
                    .easeInOut(duration: gutterAnimDuration), value: showSpine
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
            let cx = max(1, geo.size.width / 2)

            switch kind {
            case .between:
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    separator,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))

                let fadePrimary = LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .primary, location: 0.0),
                        .init(color: .primary.opacity(0), location: 1.0),
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    fadePrimary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))

            case .beforeFirst:
                let fadeSeparatorIn = LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: separator.opacity(0), location: 0.0),
                        .init(color: separator, location: 1.0),
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    fadeSeparatorIn,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
