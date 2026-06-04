//
//  ExplanationCardView.swift
//  EnglishHelper — Presentation
//
//  Renders an ExpressionExplanation: the studied-language headline (optional play + save), a
//  Copy-all action with a brief confirmation, and the labelled native-language sections. Shared by
//  "Понять"/Get it (Explain mode) and the "Смотреть"/See it explain-a-block sheet.
//

import SwiftUI
import UIKit
import Domain
import DesignSystem

struct ExplanationCardView: View {
    private let studied: String
    private let explanation: ExpressionExplanation
    private let isPlaying: Bool
    private let onPlay: (() -> Void)?
    private let isSaved: Bool?
    private let onToggleSave: (() -> Void)?
    @State private var didCopy = false

    init(
        studied: String,
        explanation: ExpressionExplanation,
        isPlaying: Bool = false,
        onPlay: (() -> Void)? = nil,
        isSaved: Bool? = nil,
        onToggleSave: (() -> Void)? = nil
    ) {
        self.studied = studied
        self.explanation = explanation
        self.isPlaying = isPlaying
        self.onPlay = onPlay
        self.isSaved = isSaved
        self.onToggleSave = onToggleSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s16) {
            HStack(alignment: .top) {
                Text(studied)
                    .textStyle(Tokens.Text.title3)
                    .foregroundStyle(Tokens.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let isSaved, let onToggleSave {
                    Spacer(minLength: Tokens.Space.s8)
                    Button { onToggleSave() } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSaved ? Tokens.Content.primary : Tokens.Content.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved
                        ? Loc.t("Убрать из изучаемого", "Remove from study list")
                        : Loc.t("Сохранить в изучаемое", "Save to study list"))
                }
            }

            HStack(spacing: Tokens.Space.s20) {
                if let onPlay, !studied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button { onPlay() } label: {
                        actionLabel(isPlaying ? Loc.t("Озвучивается…", "Playing…") : Loc.t("Озвучить", "Play"),
                                    isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Loc.t("Озвучить", "Play"))
                }
                Button {
                    UIPasteboard.general.string = plainText
                    didCopy = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.6))
                        didCopy = false
                    }
                } label: {
                    actionLabel(didCopy ? Loc.t("Скопировано", "Copied") : Loc.t("Скопировать", "Copy"),
                                didCopy ? "checkmark" : "doc.on.doc",
                                color: didCopy ? Tokens.Content.primary : Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .disabled(didCopy)
                .animation(Tokens.Motion.quick, value: didCopy)
                .accessibilityLabel(didCopy
                    ? Loc.t("Скопировано", "Copied")
                    : Loc.t("Скопировать объяснение", "Copy explanation"))
            }

            Rectangle().fill(Tokens.Hairline.default).frame(height: Tokens.Hairline.width)

            section(Loc.t("Значение", "Meaning"), explanation.meaning)
            section(Loc.t("Тон и регистр", "Tone & register"), explanation.register)
            section(Loc.t("В контексте", "In context"), explanation.context)
            section(Loc.t("Аналогия", "Analogy"), explanation.analogy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    private func actionLabel(_ text: String, _ icon: String, color: Color = Tokens.Content.secondary) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
    }

    @ViewBuilder private func section(_ label: String, _ text: String) -> some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                Text(label.uppercased())
                    .textStyle(Tokens.Text.caption2)
                    .foregroundStyle(Tokens.Content.tertiary)
                Text(text)
                    .textStyle(Tokens.Text.body)
                    .foregroundStyle(Tokens.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The whole explanation as plain text — studied headline + each non-empty section with its
    /// (uppercased) title — for copying to the clipboard exactly as shown.
    private var plainText: String {
        var parts: [String] = []
        let head = studied.trimmingCharacters(in: .whitespacesAndNewlines)
        if !head.isEmpty { parts.append(head) }
        func add(_ label: String, _ text: String) {
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return }
            parts.append("\(label.uppercased())\n\(body)")
        }
        add(Loc.t("Значение", "Meaning"), explanation.meaning)
        add(Loc.t("Тон и регистр", "Tone & register"), explanation.register)
        add(Loc.t("В контексте", "In context"), explanation.context)
        add(Loc.t("Аналогия", "Analogy"), explanation.analogy)
        return parts.joined(separator: "\n\n")
    }
}
