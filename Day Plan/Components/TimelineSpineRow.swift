import SwiftData
import SwiftUI

// MARK: - Row with vertical spine, dots, and a native-looking card
struct TimelineSpineRow: View {
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let dayStart: Date
    let now: Date

    // Layout
    private let leftColumnWidth: CGFloat = 28
    private let dotSize: CGFloat = 10
    private let lineWidth: CGFloat = 2
    private let dotTopOffset: CGFloat = 14

    private var start: Date { sp.startTime }
    private var end: Date { sp.startTime.addingTimeInterval(sp.duration) }

    private enum Status { case past, current, upcoming }
    private var status: Status {
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    private var progress: Double {
        guard status == .current else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    // Colors (use Color, not role ShapeStyles)
    private var dotColor: Color {
        switch status {
        case .current:
            return .accentColor  // blue (follows app tint)
        case .past, .upcoming:
            return .secondary  // gray
        }
    }
    private var separator: Color { Color(uiColor: .separator) }

    private var countdownTarget: Date? {
        switch status {
        case .current:
            let remaining = end.timeIntervalSince(now)
            return remaining > 0 ? Date().addingTimeInterval(remaining) : nil
        case .upcoming:
            let until = start.timeIntervalSince(now)
            return until > 0 ? Date().addingTimeInterval(until) : nil
        case .past:
            return nil
        }
    }

    // Add this helper near your other computed vars
    private var spineColor: Color {
        status == .past ? .accentColor : separator
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // LEFT: spine + dot
            ZStack {
                // inside the ZStack -> GeometryReader in TimelineSpineRow
                GeometryReader { geo in
                    let h = geo.size.height
                    let cx = leftColumnWidth / 2
                    let cy = h / 2

                    // Decide status buckets
                    let isPast = (status == .past)
                    let isActive = (status == .current)
                    let hasDot = !isPast  // dot only when not past

                    // Where the gap is (if any)
                    let topEndY: CGFloat = hasDot ? (cy - dotSize / 2) : cy
                    let bottomStartY: CGFloat = hasDot ? (cy + dotSize / 2) : cy

                    // Colors per segment
                    let topColor: Color =
                        isPast
                        ? .accentColor : (isActive ? .accentColor : separator)
                    let bottomColor: Color = isPast ? .accentColor : separator

                    // TOP segment (omit when first)
                    if !isFirst {
                        Path { p in
                            p.move(to: CGPoint(x: cx, y: 0))
                            p.addLine(to: CGPoint(x: cx, y: topEndY))
                        }
                        .stroke(
                            topColor,
                            style: StrokeStyle(
                                lineWidth: lineWidth, lineCap: .round))
                    }

                    // BOTTOM segment (omit when last)
                    if !isLast {
                        Path { p in
                            p.move(to: CGPoint(x: cx, y: bottomStartY))
                            p.addLine(to: CGPoint(x: cx, y: h))
                        }
                        .stroke(
                            bottomColor,
                            style: StrokeStyle(
                                lineWidth: lineWidth, lineCap: .round))
                    }

                    // Dot only for current/upcoming (not past)
                    if hasDot {
                        Circle()
                            .fill(dotColor)  // e.g. current = .accentColor; upcoming = .secondary
                            .frame(width: dotSize, height: dotSize)
                            .position(x: cx, y: cy)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            }
            .frame(width: leftColumnWidth, alignment: .center)

            // RIGHT: card
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
                            .foregroundStyle(.tint)  // uses the view’s tint color
                    }
                }

                //                if let desc = sp.plan?.planDescription, !desc.isEmpty {
                //                    Text(desc).font(.subheadline).foregroundStyle(.secondary)
                //                }

                Text(
                    "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(TimeUtil.formatMinutes(Int(sp.duration / 60)))"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                //                if let target = countdownTarget {
                //                    HStack(spacing: 6) {
                //                        Image(
                //                            systemName: status == .current
                //                                ? "hourglass" : "clock")
                //                        Text(status == .current ? "Ends in" : "Starts in")
                //                        Text(target, style: .timer).monospacedDigit()
                //                    }
                //                    .font(.footnote)
                //                    .foregroundStyle(.secondary)
                //                }

                if status == .current {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .animation(.linear(duration: 0.6), value: progress)
                        .accessibilityLabel("Progress")
                        .accessibilityValue("\(Int(progress * 100)) percent")
                }
            }
            .padding(12)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),  // <- matches List cell in both modes
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            .opacity(status == .past ? 0.6 : 1)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
        }
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

#if DEBUG
    import SwiftUI

    struct TimelineSpineRow_Previews: PreviewProvider {
        static var previews: some View {
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: .now)
            let now = Date()

            // Plans (required — your ScheduledPlan likely expects a non-optional `Plan`)
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
            let current = ScheduledPlan(
                plan: p2,
                startTime: cal.date(
                    byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 90 * 60)
            let upcoming = ScheduledPlan(
                plan: p3,
                startTime: cal.date(
                    byAdding: .hour, value: 13, to: startOfDay)!,
                duration: 60 * 60)

            return VStack(alignment: .leading, spacing: 24) {
                TimelineSpineRow(
                    sp: past, isFirst: true, isLast: false,
                    dayStart: startOfDay, now: now)
                TimelineSpineRow(
                    sp: current, isFirst: false, isLast: false,
                    dayStart: startOfDay, now: now)
                TimelineSpineRow(
                    sp: upcoming, isFirst: false, isLast: true,
                    dayStart: startOfDay, now: now)
            }
            .padding()
            .previewDisplayName("TimelineSpineRow States")
        }
    }
#endif
