//
//  PlainText.swift
//  EnglishHelper — Domain
//
//  Enforces the "plain text only" output contract: card fields must never carry markdown, emoji,
//  or decorative symbols, even if the model slips. Applied in template decoders.
//
//  IMPORTANT: only UNAMBIGUOUS markdown is stripped. Earlier this blanket-deleted every `*`, `_`,
//  `~`, `|`, `#`, `>` anywhere in the string, which mutilated legitimate text ("C#", "~5 min",
//  "1 > 2", "rock_and_roll", "#1 priority"). Now single characters survive unless they form a real
//  markdown construct (paired emphasis runs, or a leading header/blockquote followed by a space).
//

import Foundation

public enum PlainText {
    /// Unambiguous markdown formatting runs that essentially never occur in natural phrase text, so
    /// they're always safe to remove globally.
    static let formattingMarkers = ["***", "**", "___", "__", "```", "`", "~~"]

    /// Strip markdown markers + emoji and collapse whitespace. Idempotent.
    public static func clean(_ s: String) -> String {
        var out = s
        for marker in formattingMarkers {
            out = out.replacingOccurrences(of: marker, with: "")
        }
        // Strip a leading markdown header/blockquote ("# ", "> ") per line — but only when followed by
        // whitespace, so "#1" / ">5" stay intact.
        out = out.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String(dropLeadingBlockMarker($0)) }
            .joined(separator: "\n")
        // Drop emoji / pictographic scalars (keep ordinary punctuation and letters).
        out = String(String.UnicodeScalarView(out.unicodeScalars.filter { !isEmoji($0) }))
        // Collapse runs of whitespace introduced by removals.
        let collapsed = out.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True if the string still contains markdown/decoration or emoji that `clean` would remove.
    public static func hasDecoration(_ s: String) -> Bool {
        if formattingMarkers.contains(where: s.contains) { return true }
        let hasLeadingBlock = s.split(separator: "\n", omittingEmptySubsequences: false)
            .contains { dropLeadingBlockMarker($0) != $0 }
        if hasLeadingBlock { return true }
        return s.unicodeScalars.contains(where: isEmoji)
    }

    /// Drop a leading markdown header (`#`…) or blockquote (`>`) marker from a line, but ONLY when the
    /// marker run is followed by whitespace — real markdown structure — so "#1 priority" is left alone.
    private static func dropLeadingBlockMarker(_ line: Substring) -> Substring {
        let afterWS = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = afterWS.first, first == "#" || first == ">" else { return line }
        let afterMarkers = afterWS.drop(while: { $0 == "#" || $0 == ">" })
        guard let next = afterMarkers.first, next == " " || next == "\t" else { return line }
        return afterMarkers.drop(while: { $0 == " " || $0 == "\t" })
    }

    private static func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        // Pictographic emoji live above U+203C; this avoids stripping ASCII like '#'/'*' as "emoji".
        scalar.properties.isEmojiPresentation
            || (scalar.properties.isEmoji && scalar.value > 0x203C)
    }
}
