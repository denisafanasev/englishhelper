//
//  GlassCard.swift
//  EnglishHelper — DesignSystem
//

import SwiftUI

/// A Liquid-Glass card: glass surface (solid under Reduce Transparency) + card radius + elevation.
public struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Tokens.Space.s16)
            .glassPanel(cornerRadius: Tokens.Radius.card)
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
