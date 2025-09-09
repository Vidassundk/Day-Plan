import Foundation

/// Emoji utilities for validating and extracting user input.
extension Character {
    /// True if any Unicode scalar in the grapheme is marked as Emoji.
    /// Works for flags, skin tones, and ZWJ sequences.
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmoji }
    }
}

extension String {
    /// The last emoji grapheme in the string (if any).
    var lastEmoji: String? {
        for ch in self.reversed() where ch.isEmoji {
            return String(ch)
        }
        return nil
    }

    /// Clamp a string to a single emoji (or empty if none present).
    var clampedToSingleEmoji: String {
        lastEmoji ?? ""
    }

    /// True if the string is exactly one grapheme and that grapheme is an emoji.
    var isExactlyOneEmoji: Bool {
        count == 1 && first?.isEmoji == true
    }
}
