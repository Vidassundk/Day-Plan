import SwiftData
import SwiftUI

struct TimelineSpineRow: View {
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let dayStart: Date
    let now: Date
    let showSpine: Bool

    // Neighbor color hints (kept, used for non-active neighbors)
    let topFromColor: Color?
    let bottomToColor: Color?

    // NEW: single-color hinge right at the junction when the neighbor is ACTIVE.
    // If set, we draw ...tint→mid... (on bottom) or ...mid→tint... (on top).
    let topJunctionMid: Color?
    let bottomJunctionMid: Color?

    init(
        sp: ScheduledPlan,
        isFirst: Bool,
        isLast: Bool,
        dayStart: Date,
        now: Date,
        showSpine: Bool = true,
        topFromColor: Color? = nil,
        bottomToColor: Color? = nil,
        topJunctionMid: Color? = nil,
        bottomJunctionMid: Color? = nil
    ) {
        self.sp = sp
        self.isFirst = isFirst
        self.isLast = isLast
        self.dayStart = dayStart
        self.now = now
        self.showSpine = showSpine
        self.topFromColor = topFromColor
        self.bottomToColor = bottomToColor
        self.topJunctionMid = topJunctionMid
        self.bottomJunctionMid = bottomJunctionMid
    }

    private enum DotStyle { case circle, squircle }
    private let dotStyle: DotStyle = .squircle

    // Corner radius ~app-icon feel; tweak 0.27–0.33 to taste
    private var dotCornerRadius: CGFloat { dotDiameter * 0.40 }

    private enum NowTagStyle { case subtleTint, solidTint }
    private let nowTagStyle: NowTagStyle = .subtleTint  // change to .solidTint if you want a bolder look

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

    private let gapWidth: CGFloat = 12
    private let lineWidth: CGFloat = 2
    private let gutterAnimDuration: Double = 0.32

    // Bigger dot to fit the emoji
    private let dotDiameter: CGFloat = 30  // unchanged
    private var dotEmojiScale: CGFloat { 0.48 }  // was ~0.58 → smaller emoji
    private var dotContentInset: CGFloat { dotDiameter * 0.08 }  // padding inside the dot
    private var dotEmojiFont: Font {
        .system(size: dotDiameter * dotEmojiScale)
    }
    private let emojiBaselineNudge: CGFloat = -0.5  // tweak to taste (0, -0.5, -1)

    private var leftColumnWidth: CGFloat { dotDiameter + 16 }  // keep some side padding

    // Status
    private var start: Date { sp.startTime }
    private var end: Date { sp.startTime.addingTimeInterval(sp.duration) }
    private enum Status { case past, current, upcoming }
    private var status: Status {
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    // Progress
    private var liveProgress: Double {
        guard status == .current else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    // Anim
    @State private var displayedProgress: Double = 0
    @State private var isCollapsing = false
    @State private var currentGutter: CGFloat = 0

    private var nowTag: some View {
        HStack(spacing: 4) {

            Text("Now")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(nowTextColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(nowBackground, in: Capsule())
        .overlay(
            Capsule()
                .stroke(nowBorder, lineWidth: 1)
        )
        .shadow(
            color: nowTagStyle == .solidTint ? planTint.opacity(0.25) : .clear,
            radius: 3, y: 1
        )
        .accessibilityHidden(true)
    }

    // Colors
    private var separator: Color { Color(uiColor: .separator) }
    private var planTint: Color { sp.plan?.tintColor ?? .accentColor }

    // Dot
    private var showDot: Bool { status != .past }

    // Use plan tint for current and upcoming; hide for past
    private var dotFill: Color {
        switch status {
        case .current: return planTint
        case .upcoming: return separator  // ← changed from planTint.opacity(0.9)
        case .past: return separator  // not used (showDot == false)
        }

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
        .animation(.easeInOut(duration: gutterAnimDuration), value: showSpine)
        .onAppear {
            currentGutter = showSpine ? (leftColumnWidth + gapWidth) : 0
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
        .onChange(of: showSpine) { newValue in
            isCollapsing = true
            withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                currentGutter = newValue ? (leftColumnWidth + gapWidth) : 0
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + gutterAnimDuration + 0.02
            ) {
                isCollapsing = false
            }
        }
    }

    // MARK: - Pieces

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Emoji moved into the dot — keep only the title here
                Text(sp.plan?.title ?? "Untitled")
                    .font(.headline)
                Spacer(minLength: 8)

                if status == .current {
                    nowTag
                }

            }

            Text(
                "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(Int(sp.duration / 60)))"
            )
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
        .padding(12)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .opacity(status == .past ? 0.6 : 1)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

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
                            startPoint: .top, endPoint: .center
                        )
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else if let mid = topJunctionMid {
                        let g = LinearGradient(
                            colors: [mid, planTint],
                            startPoint: .top, endPoint: .bottom
                        )
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
                            colors: [from, planTint],
                            startPoint: startPt,
                            endPoint: endPt
                        )
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
                                colors: [planTint, mid],
                                startPoint: .top, endPoint: .bottom
                            )
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
                                colors: [planTint, target],
                                startPoint: startPt,
                                endPoint: endPt
                            )
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
                                    Circle()
                                        .stroke(
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
                                        0.9), lineWidth: 1)
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
                    .drawingGroup()  // crisper edges when animating/scaling
                }

            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // Helper
    private func vline<S: ShapeStyle>(
        cx: CGFloat, fromY: CGFloat, toY: CGFloat, style: S
    ) -> some View {
        Path { p in
            p.move(to: CGPoint(x: cx, y: fromY))
            p.addLine(to: CGPoint(x: cx, y: toY))
        }
        .stroke(style, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    }

    // Accessibility
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

enum TimelineGapKind { case between, beforeFirst }

struct TimelineGapRow: View {
    let minutesUntil: Int
    let showSpine: Bool
    let kind: TimelineGapKind

    // Keep this in sync with TimelineSpineRow.leftColumnWidth (dotDiameter + 16)
    private let leftColumnWidth: CGFloat = 46  // 30 + 16
    private let gapWidth: CGFloat = 12
    private let lineWidth: CGFloat = 2
    private let gutterAnimDuration: Double = 0.32

    @State private var currentGutter: CGFloat = 0
    private var separator: Color { Color(uiColor: .separator) }

    init(minutesUntil: Int, showSpine: Bool, kind: TimelineGapKind = .between) {
        self.minutesUntil = minutesUntil
        self.showSpine = showSpine
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
            currentGutter = showSpine ? (leftColumnWidth + gapWidth) : 0
        }
        .onChange(of: showSpine) { new in
            withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                currentGutter = new ? (leftColumnWidth + gapWidth) : 0
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
