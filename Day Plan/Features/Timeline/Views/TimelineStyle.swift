import SwiftUI

enum SpineHideDirection { case left, right }

enum TimelineStyle {
    // Geometry
    static let dotDiameter: CGFloat = 30
    static let leftColumnPadding: CGFloat = 16
    static var leftColumnWidth: CGFloat { dotDiameter + leftColumnPadding }
    static let gapWidth: CGFloat = 12
    static let lineWidth: CGFloat = 2
    static let viewModeRowHeight: CGFloat = 82
    static let cardVerticalPadView: CGFloat = 8

    // --- Debug slow-motion (toggleable) ---
    /// Enable to slow down all timeline animations for debugging.
    static var debugSlowMoEnabled: Bool = false
    /// Multiplier applied to animation durations when slow-mo is enabled.
    static var slowMoFactor: Double = 6.0

    /// Scales a duration by the slow-mo factor when slow-mo is enabled.
    static func scaled(_ d: Double) -> Double {
        debugSlowMoEnabled ? (d * slowMoFactor) : d
    }

    // Animations (centralized)
    static var spineFadeDuration: Double { scaled(0.7) }
    static var cardRepositionDuration: Double { scaled(1) }
    static var gutterAnimationDuration: Double { scaled(1) }
    static var gutterCollapseDelay: Double { scaled(1) }
    static var progressAnimDuration: Double { scaled(1) }
    static func generic(_ base: Double) -> Double { scaled(base) }

    // Edit scale (px/min)
    static let editMinuteHeight: CGFloat = 0.9

    // Hide/slide direction for the spine when it fades away
    static let hideSlideDistance: CGFloat = -16
    static var spineHideDirection: SpineHideDirection = .right
}
