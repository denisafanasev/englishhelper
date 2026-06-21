//
//  CopyButton.swift
//  EnglishHelper — DesignSystem
//
//  Copy-to-clipboard with built-in confirmation: flips to a check + "Copied" for a moment and
//  fires a success haptic, so every copy across the app gives the SAME feedback. Two styles:
//  `.labeled` (icon + text, for action rows) and `.icon` (compact, inline next to a line of text).
//

import SwiftUI
import UIKit

public struct CopyButton: View {
    public enum Style { case labeled, icon }

    private let text: String
    private let style: Style
    private let accessibilityName: String?

    @State private var copied = false

    /// - Parameters:
    ///   - text: the string placed on the clipboard.
    ///   - style: `.labeled` (icon + word) or `.icon` (icon only).
    ///   - accessibilityLabel: spoken label for the idle state (defaults to "Copy").
    public init(_ text: String, style: Style = .labeled, accessibilityLabel: String? = nil) {
        self.text = text
        self.style = style
        self.accessibilityName = accessibilityLabel
    }

    public var body: some View {
        Button(action: copy) {
            switch style {
            case .labeled:
                Label(copied ? DSLoc.t("Скопировано", "Copied") : DSLoc.t("Скопировать", "Copy"),
                      systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(copied ? Tokens.Signal.success : Tokens.Content.secondary)
                    .contentTransition(.symbolEffect(.replace))
            case .icon:
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: Tokens.Icon.cardAction, weight: .medium))
                    .foregroundStyle(copied ? Tokens.Signal.success : Tokens.Content.tertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!copied)   // brief lock-out instead of dimming, so "Copied" stays readable
        .accessibilityLabel(copied
            ? DSLoc.t("Скопировано", "Copied")
            : (accessibilityName ?? DSLoc.t("Скопировать", "Copy")))
    }

    private func copy() {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Tokens.Motion.quick) { copied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(Tokens.Motion.quick) { copied = false }
        }
    }
}
