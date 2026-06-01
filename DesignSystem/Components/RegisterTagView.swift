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
            .frame(height: Tokens.Register.height)
            .padding(.horizontal, Tokens.Register.paddingHorizontal)
            .background(style.fill, in: .rect(cornerRadius: Tokens.Register.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Register.radius)
                    .strokeBorder(style.border, lineWidth: 1)
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
