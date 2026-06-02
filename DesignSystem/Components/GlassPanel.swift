//
//  GlassPanel.swift
//  EnglishHelper — DesignSystem
//
//  Liquid-Glass surface with the required accessibility fallback: when Reduce Transparency is on,
//  the system material is replaced by a SOLID surface (text stays legible). All glass UI goes
//  through this modifier so the fallback is consistent.
//

import SwiftUI

public struct GlassPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let stroke: Bool

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                if reduceTransparency {
                    shape.fill(Tokens.Surface.primary)
                } else {
                    shape.fill(Tokens.Material.glass)
                }
            }
            .overlay {
                if stroke {
                    shape.strokeBorder(Tokens.Glass.border, lineWidth: Tokens.Hairline.width)
                }
            }
            .clipShape(shape)
    }
}

public extension View {
    /// Apply the standard glass surface (auto-solid under Reduce Transparency).
    func glassPanel(cornerRadius: CGFloat = Tokens.Radius.card, stroke: Bool = true) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, stroke: stroke))
    }
}
