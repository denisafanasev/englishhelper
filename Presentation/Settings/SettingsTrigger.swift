//
//  SettingsTrigger.swift
//  EnglishHelper — Presentation
//
//  Adds the Settings gear to a screen's toolbar (the sheet itself is hosted once at the root).
//  Applied inside each tab's NavigationStack so it appears consistently across screens.
//

import SwiftUI

struct SettingsTrigger: ViewModifier {
    @Environment(AppUIState.self) private var ui

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { ui.showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Настройки")
            }
        }
    }
}

extension View {
    func settingsTrigger() -> some View { modifier(SettingsTrigger()) }
}
