// PATCH 2/2 — TimelineSpineRow.swift
// Render rule for the vertical gutter when overlaps occur:
// - Only the *primary* current row (passed in) shows a half-filled spine.
// - Other current rows render the spine as fully filled (like past), BUT keep the dot.

import SwiftData
import SwiftUI

struct TimelineSpineRow: View {
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let dayStart: Date
    let now: Date
    let showSpine: Bool
    let isPrimaryCurrent: Bool  // NEW: parent marks which current is the primary one

    init(
        sp: ScheduledPlan,
        isFirst: Bool,
        isLast: Bool,
        dayStart: Date,
        now: Date,
        showSpine: Bool = true,
        isPrimaryCurrent: Bool = false
    ) {
        self.sp = sp
        self.isFirst = isFirst
        self.isLast = isLast
        self.dayStart = dayStart
        self.now = now
        self.showSpine = showSpine
        self.isPrimaryCurrent = isPrimaryCurrent
    }

    // Layout constants
    private let leftColumnWidth: CGFloat = 28
    private let gapWidth: CGFloat = 12
    private let dotSize: CGFloat = 12
    private let lineWidth: CGFloat = 2
    private let gutterAnimDuration: Double = 0.32

    // Timeline status
    private var start: Date { sp.startTime }
    private var end: Date { sp.startTime.addingTimeInterval(sp.duration) }

    private enum Status { case past, current, upcoming }
    private var status: Status {
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    // Live progress (source of truth)
    private var liveProgress: Double {
        guard status == .current else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    // Animation coordination
    @State private var displayedProgress: Double = 0
    @State private var isCollapsing = false
    @State private var currentGutter: CGFloat = 0

    // Colors
    private var separator: Color { Color(uiColor: .separator) }
    private var dotColor: Color {
        switch status {
        case .current: return .accentColor
        case .past, .upcoming: return .secondary
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
            let target = newValue ? (leftColumnWidth + gapWidth) : 0
            withAnimation(.easeInOut(duration: gutterAnimDuration)) {
                currentGutter = target
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + gutterAnimDuration + 0.02
            ) { isCollapsing = false }
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
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
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
                    .animation(
                        isCollapsing ? nil : .linear(duration: 0.6),
                        value: displayedProgress
                    )
                    .blur(radius: isCollapsing ? 1.2 : 0)
                    .accessibilityLabel("Progress")
                    .accessibilityValue(
                        "\(Int(displayedProgress * 100)) percent")
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

                let isPast = (status == .past)
                let isActive = (status == .current)

                // NEW rules for overlaps:
                // Secondary current rows should look like past in the spine (fully filled), but KEEP the dot.
                let isSecondaryCurrent = isActive && !isPrimaryCurrent
                let treatAsPastForSpine = isPast || isSecondaryCurrent
                let showDot = (status != .past) || isSecondaryCurrent

                let topEndY: CGFloat = showDot ? (cy - dotSize / 2) : cy
                let bottomStartY: CGFloat = showDot ? (cy + dotSize / 2) : cy

                // Colors: primary current -> half; past/secondary current -> full; upcoming -> none.
                let topColor: Color = {
                    if treatAsPastForSpine { return .accentColor }
                    if isActive && isPrimaryCurrent { return .accentColor }
                    return separator
                }()
                let bottomColor: Color = {
                    if treatAsPastForSpine { return .accentColor }
                    if isActive && isPrimaryCurrent { return separator }
                    return separator
                }()

                if !isFirst {
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: 0))
                        p.addLine(to: CGPoint(x: cx, y: topEndY))
                    }
                    .stroke(
                        topColor,
                        style: StrokeStyle(
                            lineWidth: lineWidth, lineCap: .butt))
                } else if treatAsPastForSpine {
                    // Special case: first row + past (or secondary current).
                    // Visually fade in from transparent (top) to accent (at the dot).
                    let fade = LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0), Color.accentColor,
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: 0))
                        p.addLine(to: CGPoint(x: cx, y: topEndY))
                    }
                    .stroke(
                        fade,
                        style: StrokeStyle(
                            lineWidth: lineWidth, lineCap: .butt))
                }

                if !isLast {
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: bottomStartY))
                        p.addLine(to: CGPoint(x: cx, y: h))
                    }
                    .stroke(
                        bottomColor,
                        style: StrokeStyle(
                            lineWidth: lineWidth, lineCap: .butt))
                } else if treatAsPastForSpine {
                    // Special case: last row + past (or secondary current).
                    // Fade OUT from accent (near the dot) to transparent toward the bottom.
                    let fadeOut = LinearGradient(
                        colors: [
                            Color.accentColor, Color.accentColor.opacity(0),
                        ],
                        startPoint: .center,  // mirror of your top: .top -> .center trick
                        endPoint: .bottom
                    )
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: bottomStartY))
                        p.addLine(to: CGPoint(x: cx, y: h))
                    }
                    .stroke(
                        fadeOut,
                        style: StrokeStyle(
                            lineWidth: lineWidth, lineCap: .butt))
                }

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

    // MARK: - Accessibility

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

struct TimelineGapRow: View {
    let minutesUntil: Int
    let showSpine: Bool

    // Match TimelineSpineRow layout
    private let leftColumnWidth: CGFloat = 28
    private let gapWidth: CGFloat = 12
    private let lineWidth: CGFloat = 2
    private let gutterAnimDuration: Double = 0.32

    @State private var currentGutter: CGFloat = 0
    private var separator: Color { Color(uiColor: .separator) }

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
        Text("\(TimeUtil.formatMinutes(minutesUntil)) until next plan")
            .font(.footnote.weight(.bold))
            .padding(.vertical, 10)
            .foregroundColor(.accentColor)
            .padding(.vertical, 6)
    }

    private var spine: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let cx = max(1, geo.size.width / 2)

            // Base: full separator (continuous), overshoot to overlap adjacent rows
            Path { p in
                p.move(to: CGPoint(x: cx, y: 0))
                p.addLine(to: CGPoint(x: cx, y: h))
            }
            .stroke(
                separator,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))

            // Overlay: accent -> transparent (so the base separator shows exactly)
            let fade = LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .accentColor, location: 0.0),
                    .init(color: .accentColor.opacity(0), location: 1.0),
                ]),
                startPoint: .top,
                endPoint: .bottom  // fully transparent by mid-height
            )

            Path { p in
                p.move(to: CGPoint(x: cx, y: 0))
                p.addLine(to: CGPoint(x: cx, y: h))
            }
            .stroke(
                fade, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
    import SwiftUI

    struct TimelineSpineRow_Previews: PreviewProvider {
        static var previews: some View {
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: .now)
            let now = Date()

            let p1 = Plan(
                title: "Standup", planDescription: "Sprint 42", emoji: "👥")
            let p2 = Plan(
                title: "Design Review", planDescription: "New UI", emoji: "🎨")
            let p3 = Plan(
                title: "Workout", planDescription: "Push day", emoji: "💪")

            let past = ScheduledPlan(
                plan: p1,
                startTime: cal.date(byAdding: .hour, value: 8, to: startOfDay)!,
                duration: 60 * 60)
            let currentPrimary = ScheduledPlan(
                plan: p2,
                startTime: cal.date(
                    byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 90 * 60)
            let currentSecondary = ScheduledPlan(
                plan: p3,
                startTime: cal.date(
                    byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 60 * 60)

            return VStack(alignment: .leading, spacing: 0) {
                TimelineSpineRow(
                    sp: past, isFirst: true, isLast: false,
                    dayStart: startOfDay, now: now, showSpine: true,
                    isPrimaryCurrent: false)
                TimelineSpineRow(
                    sp: currentPrimary, isFirst: false, isLast: false,
                    dayStart: startOfDay, now: now, showSpine: true,
                    isPrimaryCurrent: true)
                TimelineSpineRow(
                    sp: currentSecondary, isFirst: false, isLast: true,
                    dayStart: startOfDay, now: now, showSpine: true,
                    isPrimaryCurrent: false)
            }
            .padding()
            .previewDisplayName("Spine — Primary vs Secondary Current")
        }
    }
#endif
