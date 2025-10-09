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

    // Animations
    static let spineFadeDuration: Double = 0.22
    static let cardRepositionDuration: Double = 0.38

    // Edit scale (px/min)
    static let editMinuteHeight: CGFloat = 0.9

    // Hide/slide direction for the spine when it fades away
    static let hideSlideDistance: CGFloat = -16
    static var spineHideDirection: SpineHideDirection = .right
}
