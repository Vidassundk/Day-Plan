import SwiftUI
import UIKit

/// Utilities for converting between `Color` and hex strings.
/// Supported format: `#RRGGBB` (alpha is ignored/assumed 1.0).
public enum ColorHex {
    /// Parse a `#RRGGBB` string into a SwiftUI `Color`.
    public static func color(from hex: String) -> Color? {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Convert a `Color` into `#RRGGBB`, if representable.
    public static func hex(from color: Color) -> String? {
        let ui = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255))
        )
    }
}

extension Color {
    /// Initialize from `#RRGGBB` string; returns `nil` if invalid.
    public init?(hex: String) {
        guard let c = ColorHex.color(from: hex) else { return nil }
        self = c
    }

    /// Convert to a `#RRGGBB` string if possible.
    public func toHexRGB() -> String? { ColorHex.hex(from: self) }
}
