//
//  GlassCard.swift
//  EnglishHelper — DesignSystem
//

import SwiftUI

/// A Liquid-Glass card: system material + hairline glass border + card radius + elevation.
public struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Tokens.Space.s16)
            .background(Tokens.Material.glass, in: .rect(cornerRadius: Tokens.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card)
                    .strokeBorder(Tokens.Glass.border, lineWidth: Tokens.Hairline.width)
            )
            .shadow(Tokens.Shadow.cardLight, Tokens.Shadow.cardDark, scheme: scheme)
    }
}

#Preview {
    GlassCard {
        Text("Could you give me a hand?")
            .textStyle(Tokens.Text.headline)
            .foregroundStyle(Tokens.Content.primary)
    }
    .padding()
    .screenBackground()
}
