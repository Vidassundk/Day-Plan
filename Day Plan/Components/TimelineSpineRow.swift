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

    // Layout
    private let leftColumnWidth: CGFloat = 28
    private let gapWidth: CGFloat = 12
    private let dotSize: CGFloat = 12
    private let lineWidth: CGFloat = 2
    private let gutterAnimDuration: Double = 0.32

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

    // Colors
    private var separator: Color { Color(uiColor: .separator) }
    private var planTint: Color { sp.plan?.tintColor ?? .accentColor }

    // Dot
    private var showDot: Bool { status != .past }
    private var dotColor: Color { status == .current ? planTint : separator }

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
                Text(sp.plan?.emoji ?? "🧩").font(.title3)
                Text(sp.plan?.title ?? "Untitled").font(.headline)
                Spacer(minLength: 8)

                if status == .current {
                    Text("Now")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            Color.accentColor.opacity(0.15), in: Capsule()
                        )
                        .accessibilityHidden(true)
                } else if status == .past {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
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
                let hingeWidth: CGFloat = 0.18

                let topEndY: CGFloat = showDot ? (cy - dotSize / 2) : cy
                let bottomStartY: CGFloat = showDot ? (cy + dotSize / 2) : cy

                let minFadePts: CGFloat = 14  // at least 14pt of visible fade
                let topLen = max(topEndY, 1)
                let topHinge = min(0.55, max(0.22, minFadePts / topLen))  // 22–55% of segment

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
                    // --- TOP SEGMENT ---  (.current)
                    if isFirst {
                        let g = LinearGradient(
                            colors: [Color.primary.opacity(0), planTint],
                            startPoint: .top, endPoint: .center
                        )
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else if let mid = topJunctionMid {
                        // ACTIVE above → full-span blend from shared mid to my tint
                        let g = LinearGradient(
                            colors: [mid, planTint],
                            startPoint: .top, endPoint: .bottom
                        )
                        vline(cx: cx, fromY: 0, toY: topEndY, style: g)
                    } else {
                        // If the "from" color is a real tint (not primary/separator), use 2× .top
                        let from = topFromColor ?? .primary
                        let neighborIsTint =
                            !(from == .primary || from == separator)
                        let startPt: UnitPoint =
                            neighborIsTint
                            ? UnitPoint(x: 0.5, y: -1.0)  // 2× .top
                            : .top

                        let endPt: UnitPoint =
                            neighborIsTint
                            ? .bottom  // 2× .top
                            : .center

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
                            // ACTIVE → ACTIVE below: full-span blend from my tint to the shared mid
                            let g = LinearGradient(
                                colors: [planTint, mid],
                                startPoint: .top, endPoint: .bottom
                            )
                            vline(
                                cx: cx, fromY: bottomStartY - px, toY: h + px,
                                style: g)
                        } else {
                            // If the target is a real tint (not primary/separator), use 2× .bottom
                            let target = bottomToColor ?? separator
                            let neighborIsTint =
                                !(target == .primary || target == separator)

                            let startPt: UnitPoint =
                                neighborIsTint
                                ? .top  // 2× .top
                                : .center

                            let endPt: UnitPoint =
                                neighborIsTint
                                ? UnitPoint(x: 0.5, y: 2.0)  // 2× .bottom
                                : .bottom

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

                // --- DOT ---
                if showDot {
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: cx, y: cy)
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

    private let leftColumnWidth: CGFloat = 28
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
