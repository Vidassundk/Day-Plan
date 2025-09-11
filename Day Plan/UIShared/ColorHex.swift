import SwiftUI
import UIKit

/// Utilities for converting between `Color` and hex strings.
///
/// Supported inputs (case-insensitive, leading `#` optional):
/// - `RRGGBB`
/// - `RRGGBBAA` (trailing AA = alpha; we *ignore* alpha when emitting hex)
///
/// Design notes:
/// - Timeline visuals expect solid tints for contrast, so we **ignore alpha**
///   when serializing, and we **parse** both 6/8-digit inputs gracefully.
/// - If you later want alpha-aware UI, you can plumb it through explicitly.
public enum ColorHex {
    /// Parse a hex string into a SwiftUI `Color`.
    public static func color(from raw: String) -> Color? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        s = s.uppercased()

        guard s.count == 6 || s.count == 8, let v = Int(s, radix: 16) else {
            return nil
        }

        let r: Double
        let g: Double
        let b: Double
        let a: Double

        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255.0
            g = Double((v >> 8) & 0xFF) / 255.0
            b = Double(v & 0xFF) / 255.0
            a = 1.0
        } else {
            // Treat as RRGGBBAA (alpha last)
            r = Double((v >> 24) & 0xFF) / 255.0
            g = Double((v >> 16) & 0xFF) / 255.0
            b = Double((v >> 8) & 0xFF) / 255.0
            a = Double(v & 0xFF) / 255.0
        }

        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Convert a `Color` into `#RRGGBB` if representable.
    /// We intentionally drop alpha to keep schedule tints readable.
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
    /// Initialize from a hex string. Accepts `RRGGBB` or `RRGGBBAA`.
    public init?(hex: String) {
        guard let c = ColorHex.color(from: hex) else { return nil }
        self = c
    }

    /// Convert to a `#RRGGBB` string (alpha intentionally dropped).
    public func toHexRGB() -> String? { ColorHex.hex(from: self) }
}
