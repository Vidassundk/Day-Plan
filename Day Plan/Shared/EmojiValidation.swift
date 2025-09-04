//
//  EmojiValidation.swift
//  Day Plan
//
//  Created by Vidas Sun on 03/09/2025.
//

import Foundation

extension Character {
    /// True if any scalar in the grapheme is an Emoji scalar. Works for flags, skin tones, ZWJ sequences, etc.
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmoji }
    }
}

extension String {
    /// Returns the last emoji grapheme in the string (if any), otherwise nil.
    var lastEmoji: String? {
        for ch in self.reversed() where ch.isEmoji {
            return String(ch)
        }
        return nil
    }

    /// Returns this string clamped to a single emoji (or empty if none).
    var clampedToSingleEmoji: String {
        lastEmoji ?? ""
    }

    /// True if the string is exactly one grapheme and that grapheme is an emoji.
    var isExactlyOneEmoji: Bool {
        count == 1 && first?.isEmoji == true
    }
}
