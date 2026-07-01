//
//  CardTagView.swift
//  EnglishHelper — DesignSystem
//
//  A neutral pill label for a result card's header — e.g. the scenario ("Перевод" / "Объяснение") on
//  the Translate / Explain cards. Matches the register-tag look on the generation cards, but carries
//  free text instead of a register, so it's clearly a section label and never read as a tone.
//

import SwiftUI

public struct CardTagView: View {
    private let text: String
    public init(_ text: String) { self.text = text }

    public var body: some View {
        let style = Tokens.Register.casual   // neutral surface pill (a label, not a register)
        Text(text.uppercased())
            .font(Tokens.Register.labelFont)
            .tracking(Tokens.Register.labelTracking)
            .foregroundStyle(style.foreground)
            .frame(minHeight: Tokens.Register.height)   // minHeight so it grows with Dynamic Type
            .padding(.horizontal, Tokens.Register.paddingHorizontal)
            .background(style.fill, in: .rect(cornerRadius: Tokens.Register.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Register.radius)
                    .strokeBorder(style.border, lineWidth: Tokens.Hairline.width)
            )
    }
}
