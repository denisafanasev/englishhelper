//
//  PlayCopyExplainRow.swift
//  EnglishHelper — Presentation
//
//  The shared "Play · Copy · Explain" action row used under a studied-language block (See it) and a
//  History request. It shows text labels when they fit and falls back to icon-only when they don't
//  (ViewThatFits) — so the three actions always stay on ONE line, never wrapping or truncating
//  mid-word, in any interface language and on any width. Playing is shown by the filled speaker icon;
//  the Play label stays static so the row width doesn't change on play/stop (which would otherwise
//  make the labels-vs-icons choice flip).
//

import SwiftUI
import DesignSystem

struct PlayCopyExplainRow: View {
    let isPlaying: Bool
    let onPlay: () -> Void
    let copyText: String
    let copyAccessibility: String
    let onExplain: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(labeled: true)
            row(labeled: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(labeled: Bool) -> some View {
        HStack(spacing: Tokens.Space.s16) {
            Button(action: onPlay) {
                actionLabel(Loc.t("Озвучить", "Play"),
                            isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2",
                            labeled: labeled)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Loc.t("Озвучить", "Play"))

            CopyButton(copyText,
                       style: labeled ? .labeled : .icon,
                       accessibilityLabel: copyAccessibility)

            Button(action: onExplain) {
                actionLabel(Loc.t("Объяснить", "Explain"), "lightbulb", labeled: labeled)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Loc.t("Объяснить", "Explain"))
        }
    }

    @ViewBuilder private func actionLabel(_ text: String, _ icon: String, labeled: Bool) -> some View {
        if labeled {
            Label(text, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(Tokens.Content.secondary)
        } else {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Tokens.Content.secondary)
        }
    }
}
