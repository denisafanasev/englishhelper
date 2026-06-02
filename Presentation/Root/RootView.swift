//
//  RootView.swift
//  EnglishHelper — Presentation
//
//  App shell: tab bar (Liquid Glass) + global theme + the Settings sheet (opened by the gear on
//  each screen via shared AppUIState).
//

import SwiftUI

public struct RootView: View {
    @State private var voice: VoiceViewModel
    @State private var translate: TranslateViewModel
    @State private var photo: PhotoTranslateViewModel
    @State private var library: StudyListViewModel
    @State private var history: HistoryViewModel
    @State private var settings: SettingsViewModel

    @State private var theme = ThemeStore()
    @State private var ui = AppUIState()

    public init(
        voice: VoiceViewModel,
        translate: TranslateViewModel,
        photo: PhotoTranslateViewModel,
        library: StudyListViewModel,
        history: HistoryViewModel,
        settings: SettingsViewModel
    ) {
        _voice = State(initialValue: voice)
        _translate = State(initialValue: translate)
        _photo = State(initialValue: photo)
        _library = State(initialValue: library)
        _history = State(initialValue: history)
        _settings = State(initialValue: settings)
    }

    public var body: some View {
        @Bindable var ui = ui
        TabView {
            Tab("Голос", systemImage: "mic.fill") { VoiceView(model: voice) }
            Tab("Перевод", systemImage: "character.bubble") { TranslateView(model: translate) }
            Tab("Камера", systemImage: "camera") { PhotoTranslateView(model: photo) }
            Tab("Изучаю", systemImage: "rectangle.stack") { StudyListView(model: library) }
            Tab("История", systemImage: "clock.arrow.circlepath") { HistoryView(model: history) }
        }
        .environment(ui)
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $ui.showSettings) {
            SettingsView(model: settings, theme: theme) { ui.showSettings = false }
        }
    }
}
