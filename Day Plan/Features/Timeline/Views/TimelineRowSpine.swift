import SwiftData
import SwiftUI

/// Spine-only rendering for a scheduled plan row (no card surface).
/// Keeps a continuous line and aligns vertically with cards by baking the card vertical padding
/// into the **row height** instead of using padding (no visual gaps in the line).
struct TimelineSpineOnlyRow: View {
    // Inputs
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let now: Date
    let showSpine: Bool
    let isEditing: Bool  // spines do not relocate in Edit
    let editMinuteHeight: CGFloat

    // VM
    @StateObject private var vm: TimelineSpineRowViewModel

    // Derived
    private var status: TimelineSpineRowViewModel.Status { vm.status(now: now) }
    private var planTint: Color { sp.plan?.tintColor ?? .accentColor }
    private var separator: Color { Color(uiColor: .separator) }

    // Keep spines at view-mode geometry; add card padding into the height.
    private var rowHeight: CGFloat {
        TimelineStyle.viewModeRowHeight
            + (TimelineStyle.cardVerticalPadView * 2)
    }

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
                let cx = max(1, TimelineStyle.leftColumnWidth / 2)
                let cy = h / 2
                let px: CGFloat = 1 / UIScreen.main.scale

                let showDot = status != .past
                let topEndY: CGFloat =
                    showDot ? (cy - TimelineStyle.dotDiameter / 2) : cy
                let bottomStartY: CGFloat =
                    showDot ? (cy + TimelineStyle.dotDiameter / 2) : cy

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
                        cornerRadius: TimelineStyle.dotDiameter * 0.40,
                        style: .continuous
                    )
                    .fill(status == .current ? planTint : separator)
                    .frame(
                        width: TimelineStyle.dotDiameter,
                        height: TimelineStyle.dotDiameter
                    )
                    .overlay {
                        let side =
                            TimelineStyle.dotDiameter - 2
                            * (TimelineStyle.dotDiameter * 0.08)
                        Text(sp.plan?.emoji ?? "🧩")
                            .font(
                                .system(size: TimelineStyle.dotDiameter * 0.48)
                            )
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
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(width: TimelineStyle.leftColumnWidth, alignment: .center)
        .opacity(showSpine ? 1 : 0)
        .offset(x: hideOffsetX)
        .animation(
            .easeInOut(duration: TimelineStyle.spineFadeDuration),
            value: showSpine
        )
    }

    private var hideOffsetX: CGFloat {
        guard !showSpine else { return 0 }
        let dir: CGFloat = (TimelineStyle.spineHideDirection == .left) ? -1 : 1
        return dir * TimelineStyle.hideSlideDistance
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
        .stroke(
            style,
            style: StrokeStyle(
                lineWidth: TimelineStyle.lineWidth,
                lineCap: .butt
            )
        )
    }
}
