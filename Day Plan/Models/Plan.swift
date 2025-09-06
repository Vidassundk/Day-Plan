// Plan.swift
import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class Plan {
    @Attribute(.unique) var id: UUID
    var title: String
    var planDescription: String?
    var emoji: String

    // NEW: non-optional. Empty string == “use .accentColor”
    var colorHex: String

    @Relationship(deleteRule: .cascade, inverse: \ScheduledPlan.plan)
    var scheduledUsages: [ScheduledPlan] = []

    init(
        title: String,
        planDescription: String? = nil,
        emoji: String,
        colorHex: String = ""  // default: accent fallback
    ) {
        self.id = UUID()
        self.title = title
        self.planDescription = planDescription
        self.emoji = emoji
        self.colorHex = colorHex
    }

    // Always yields a visible color; empty => accent
    var tintColor: Color {
        if colorHex.isEmpty { return .accentColor }
        return Color(hex: colorHex) ?? .accentColor
    }
}

// MARK: - Color helpers
extension Color {
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    func toHexRGB() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}
