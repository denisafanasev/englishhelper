//
//  EHButton.swift
//  EnglishHelper — DesignSystem
//
//  Pill button, four kinds (mirrors the design kit: primary / glass / tonal / ghost).
//

import SwiftUI

public struct EHButton: View {
    public enum Kind: Sendable { case primary, glass, tonal, ghost }

    private let title: String
    private let icon: String?
    private let kind: Kind
    private let fillWidth: Bool
    private let action: () -> Void

    public init(_ title: String, icon: String? = nil, kind: Kind = .primary,
                fillWidth: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.fillWidth = fillWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(foreground)
            .frame(height: 50)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .padding(.horizontal, Tokens.Space.s20)
            .background(background)
            .clipShape(Capsule())
            .overlay {
                if kind == .glass {
                    Capsule().strokeBorder(Tokens.Glass.border, lineWidth: Tokens.Hairline.width)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Tokens.Content.onInvert
        case .glass, .tonal, .ghost: Tokens.Content.primary
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .primary: Tokens.Surface.invert
        case .glass:   Color.clear.glassPanelCapsule()
        case .tonal:   Tokens.Fill.default
        case .ghost:   Color.clear
        }
    }
}

private extension View {
    /// Capsule glass fill honoring Reduce Transparency.
    func glassPanelCapsule() -> some View { modifier(CapsuleGlass()) }
}

private struct CapsuleGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency { Capsule().fill(Tokens.Surface.primary) }
            else { Capsule().fill(Tokens.Material.glass) }
        }
    }
}
