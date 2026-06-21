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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    // Play sits in the same action row as copy + save (tapping the card text also
                    // starts/stops playback — see .onTapGesture below).
                    Button(action: onPlay) {
                        Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.system(size: 16, weight: .medium))
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying && !reduceMotion)
                            .foregroundStyle(isPlaying ? Tokens.Content.primary : Tokens.Content.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(DSLoc.t("Озвучить", "Play"))

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(english). \(register.localizedName). \(contextRU)")
        .accessibilityHint(DSLoc.t("Дважды коснитесь, чтобы озвучить", "Double-tap to play"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: DSLoc.t("Скопировать", "Copy")) { copyToClipboard() }
        .accessibilityAction(named: isSaved ? DSLoc.t("Убрать из изучаемого", "Remove from study list") : DSLoc.t("Сохранить", "Save")) { onToggleSave() }
    }

    // Inline copy (kept rather than a nested CopyButton so it folds into the card's combined
    // accessibility element); timing/animation match CopyButton so feedback is consistent app-wide.
    private func copyToClipboard() {
        UIPasteboard.general.string = english
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Tokens.Motion.quick) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(Tokens.Motion.quick) { copied = false }
        }
    }
}
