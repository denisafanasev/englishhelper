//
//  PlainText.swift
//  EnglishHelper — Domain
//
//  Enforces the "plain text only" output contract: card fields must never carry markdown, emoji,
//  or decorative symbols, even if the model slips. Applied in template decoders.
//

import Foundation

public enum PlainText {
    /// Markdown / decoration markers that must never survive into a stored field.
    static let markers = ["**", "__", "```", "`", "*", "_", "#", "~~", "~", "|", ">"]

    /// Strip markdown markers + emoji and collapse whitespace. Idempotent.
    public static func clean(_ s: String) -> String {
        var out = s
        for marker in markers {
            out = out.replacingOccurrences(of: marker, with: "")
        }
        // Drop emoji / pictographic scalars (keep ordinary punctuation and letters).
        out = String(String.UnicodeScalarView(out.unicodeScalars.filter { !isEmoji($0) }))
        // Collapse runs of whitespace introduced by removals.
        let collapsed = out.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True if the string still contains markdown/decoration or emoji.
    public static func hasDecoration(_ s: String) -> Bool {
        if markers.contains(where: s.contains) { return true }
        return s.unicodeScalars.contains(where: isEmoji)
    }

    private static func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        // Pictographic emoji live above U+203C; this avoids stripping ASCII like '#'/'*' as "emoji".
        scalar.properties.isEmojiPresentation
            || (scalar.properties.isEmoji && scalar.value > 0x203C)
    }
}
