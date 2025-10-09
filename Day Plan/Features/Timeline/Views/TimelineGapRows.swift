import SwiftUI

enum TimelineGapKind { case between, beforeFirst }

/// Card-only view for the gap label row.
struct TimelineGapCardRow: View {
    let minutesUntil: Int
    let isEditing: Bool
    let reserveGutter: Bool

    private let gutterAnimDuration: Double = 0.32
    @State private var currentGutter: CGFloat = 0

    private var totalGutter: CGFloat {
        TimelineStyle.leftColumnWidth + TimelineStyle.gapWidth
    }

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
    let kind: TimelineGapKind

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let cx = max(1, TimelineStyle.leftColumnWidth / 2)
            let separator = Color(uiColor: .separator)

            switch kind {
            case .between:
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 0))
                    p.addLine(to: CGPoint(x: cx, y: h))
                }
                .stroke(
                    separator,
                    style: StrokeStyle(
                        lineWidth: TimelineStyle.lineWidth,
                        lineCap: .butt
                    )
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
                    style: StrokeStyle(
                        lineWidth: TimelineStyle.lineWidth,
                        lineCap: .butt
                    )
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
                    style: StrokeStyle(
                        lineWidth: TimelineStyle.lineWidth,
                        lineCap: .butt
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 26)  // approximate natural height of the label row
        .frame(width: TimelineStyle.leftColumnWidth, alignment: .center)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
