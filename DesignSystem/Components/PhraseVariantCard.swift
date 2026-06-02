//
//  PhraseVariantCard.swift
//  EnglishHelper — DesignSystem
//
//  One "how to say it" variant: English phrase + register tag + Russian context. Tap = play TTS,
//  bookmark = save to study list.
//

import SwiftUI
import UIKit

public struct PhraseVariantCard: View {
    private let english: String
    private let register: RegisterLevel
    private let contextRU: String
    private let isSaved: Bool
    private let isPlaying: Bool
    private let onPlay: () -> Void
    private let onToggleSave: () -> Void

    @State private var copied = false

    public init(english: String, register: RegisterLevel, contextRU: String,
                isSaved: Bool, isPlaying: Bool,
                onPlay: @escaping () -> Void, onToggleSave: @escaping () -> Void) {
        self.english = english
        self.register = register
        self.contextRU = contextRU
        self.isSaved = isSaved
        self.isPlaying = isPlaying
        self.onPlay = onPlay
        self.onToggleSave = onToggleSave
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            HStack(alignment: .top) {
                RegisterTagView(register)
                Spacer(minLength: Tokens.Space.s8)
                HStack(spacing: Tokens.Space.s16) {
                    Button(action: copyToClipboard) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(copied ? Tokens.Signal.success : Tokens.Content.tertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(DSLoc.t("Скопировать английский", "Copy English"))

                    Button(action: onToggleSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSaved ? Tokens.Content.primary : Tokens.Content.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? DSLoc.t("Убрать из изучаемого", "Remove from study list") : DSLoc.t("Сохранить в изучаемое", "Save to study list"))
                }
            }

            Text(english)
                .textStyle(Tokens.Text.title3)
                .foregroundStyle(Tokens.Content.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(contextRU)
                .textStyle(Tokens.Text.subhead)
                .foregroundStyle(Tokens.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Tokens.Space.s8) {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                Text(isPlaying ? DSLoc.t("Озвучивается…", "Playing…") : DSLoc.t("Озвучить", "Play"))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tokens.Content.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(english). \(register.rawValue). \(contextRU)")
        .accessibilityHint(DSLoc.t("Дважды коснитесь, чтобы озвучить", "Double-tap to play"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: DSLoc.t("Скопировать", "Copy")) { copyToClipboard() }
        .accessibilityAction(named: isSaved ? DSLoc.t("Убрать из изучаемого", "Remove from study list") : DSLoc.t("Сохранить", "Save")) { onToggleSave() }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = english
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { copied = false }
        }
    }
}
