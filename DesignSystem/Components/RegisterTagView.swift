//
//  RegisterTagView.swift
//  EnglishHelper — DesignSystem
//

import SwiftUI

/// The three register tiers the design system actually styles.
///
/// The Domain `Register` enum has four cases (formal/neutral/casual/slang); the design defines
/// only THREE tags. Callers map `.neutral → .casual` (see `init(register:)` bridges in Presentation).
public enum RegisterLevel: String, CaseIterable, Sendable {
    case formal
    case casual
    case slang

    var style: Tokens.RegisterStyle {
        switch self {
        case .formal: Tokens.Register.formal
        case .casual: Tokens.Register.casual
        case .slang:  Tokens.Register.slang
        }
    }

    /// Spoken register name in the interface language — for VoiceOver, where the compact English tag
    /// code (FORMAL/CASUAL/SLANG) shown on the card shouldn't be read out verbatim to a non-EN user.
    public var localizedName: String {
        switch self {
        case .formal: DSLoc.t("формальный", "formal", "formel", "formal", "förmlich", "formale")
        case .casual: DSLoc.t("разговорный", "casual", "familier", "informal", "locker", "colloquiale")
        case .slang:  DSLoc.t("сленг", "slang", "argot", "argot", "Slang", "gergo")
        }
    }
}

/// A monochrome, fill-density-coded register tag (formal = solid, casual = surface, slang = outline).
public struct RegisterTagView: View {
    private let level: RegisterLevel
    public init(_ level: RegisterLevel) { self.level = level }

    public var body: some View {
        let style = level.style
        Text(level.rawValue.uppercased())
            .font(Tokens.Register.labelFont)
            .tracking(Tokens.Register.labelTracking)
            .foregroundStyle(style.foreground)
            .frame(minHeight: Tokens.Register.height)   // minHeight so the tag grows with Dynamic Type
            .padding(.horizontal, Tokens.Register.paddingHorizontal)
            .background(style.fill, in: .rect(cornerRadius: Tokens.Register.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Register.radius)
                    .strokeBorder(style.border, lineWidth: Tokens.Hairline.width)
            )
    }
}

#Preview {
    HStack(spacing: Tokens.Space.s8) {
        RegisterTagView(.formal)
        RegisterTagView(.casual)
        RegisterTagView(.slang)
    }
    .padding()
    .screenBackground()
}
