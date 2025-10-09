import SwiftUI
import UIKit

// Tiny utility to animate height changes (used for time-gap spacers)
struct AnimHeightSpacer: View {
    let height: CGFloat
    let animate: Bool
    let delay: Double
    let duration: Double

    var body: some View {
        Color.clear
            .frame(height: height)
            .animation(
                animate ? .easeInOut(duration: duration).delay(delay) : nil,
                value: height
            )
    }
}

// Hour grid with flush-left labels/ticks and a top inset so 00:00 isn’t clipped.
struct HoursGridLayer: View {
    let minuteHeight: CGFloat
    let start: Date

    static var topInset: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2).lineHeight / 2
    }

    static func requiredHeight(minuteHeight: CGFloat) -> CGFloat {
        let lh = UIFont.preferredFont(forTextStyle: .caption2).lineHeight
        return (1440 * minuteHeight) + lh
    }

    private var hourCount: Int { 25 }  // 0…24 inclusive

    private let labelWidth: CGFloat = 34
    private let labelTickGap: CGFloat = 6

    private var topInsetLocal: CGFloat { Self.topInset }

    var body: some View {
        GeometryReader { geo in
            let lineStartX = labelWidth + labelTickGap

            ZStack(alignment: .topLeading) {
                // Major hour lines
                ForEach(0..<hourCount, id: \.self) { h in
                    let y = topInsetLocal + CGFloat(h) * 60 * minuteHeight
                    Path { p in
                        p.move(to: CGPoint(x: lineStartX, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(
                        Color(uiColor: .separator).opacity(0.8),
                        lineWidth: 1
                    )
                }

                // Minor 15-minute lines
                ForEach(0..<((hourCount - 1) * 3), id: \.self) { i in
                    let y = topInsetLocal + CGFloat(i + 1) * 15 * minuteHeight
                    Path { p in
                        p.move(to: CGPoint(x: lineStartX, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(
                        Color(uiColor: .separator).opacity(0.35),
                        lineWidth: 1
                    )
                }

                // Hour labels
                ForEach(0..<hourCount, id: \.self) { h in
                    let y = topInsetLocal + CGFloat(h) * 60 * minuteHeight
                    Text(formattedHour(h))
                        .font(.caption2)
                        .frame(width: labelWidth, alignment: .trailing)
                        .position(x: labelWidth / 2, y: y)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    private func formattedHour(_ offset: Int) -> String {
        let date =
            Calendar.current.date(byAdding: .hour, value: offset, to: start)
            ?? start
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
        )
    }
}
