//
//  ScreenBackground.swift
//  EnglishHelper — DesignSystem
//
//  Built on Tokens only. DesignSystem has NO dependency on Domain/Data/Presentation.
//

import SwiftUI

/// The app's base background fill (monochrome, theme-aware), edge to edge.
public struct ScreenBackground: View {
    public init() {}
    public var body: some View {
        Tokens.Surface.background
            .ignoresSafeArea()
    }
}

public extension View {
    /// Place the standard screen background behind this view.
    func screenBackground() -> some View {
        background(ScreenBackground())
    }
}
