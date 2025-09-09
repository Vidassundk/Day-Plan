import SwiftUI

/// Access to system semantic colors through SwiftUI `Color`.
extension Color {
    /// Matches UIKit's placeholder text color for subtle prompts.
    static var placeholderText: Color { Color(uiColor: .placeholderText) }
}
