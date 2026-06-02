//
//  RootView.swift
//  EnglishHelper — Presentation
//
//  App shell: tab bar (Liquid Glass) + global theme + the Settings sheet.
//  Order: Изучаю · Текст · Голос (center, default) · Камера · История.
//  "Голос" and "Текст" are the same flow (RU → 3 English variants); "Текст" is text-input only.
//

import SwiftUI

public struct RootView: View {
    @State private var voice: VoiceViewModel
    @State private var text: VoiceViewModel
    @State private var photo: PhotoTranslateViewModel
    @State private var library: StudyListViewModel
    @State private var history: HistoryViewModel
    @State private var settings: SettingsViewModel

    @State private var theme = ThemeStore()
    @State private var tone = ToneStore()
    @State private var ui = AppUIState()
    @State private var selection = "voice"

    public init(
        voice: VoiceViewModel,
        text: VoiceViewModel,
        photo: PhotoTranslateViewModel,
        library: StudyListViewModel,
        history: HistoryViewModel,
        settings: SettingsViewModel
    ) {
        _voice = State(initialValue: voice)
        _text = State(initialValue: text)
        _photo = State(initialValue: photo)
        _library = State(initialValue: library)
        _history = State(initialValue: history)
        _settings = State(initialValue: settings)
    }

    public var body: some View {
        @Bindable var ui = ui
        TabView(selection: $selection) {
            Tab("Изучаю", systemImage: "rectangle.stack", value: "library") {
                StudyListView(model: library)
            }
            Tab("Текст", systemImage: "keyboard", value: "text") {
                VoiceView(model: text, showsMic: false)
            }
            Tab("Голос", systemImage: "mic.fill", value: "voice") {
                VoiceView(model: voice)
            }
            Tab("Камера", systemImage: "camera", value: "camera") {
                PhotoTranslateView(model: photo)
            }
            Tab("История", systemImage: "clock.arrow.circlepath", value: "history") {
                HistoryView(model: history)
            }
        }
        .environment(ui)
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $ui.showSettings) {
            SettingsView(model: settings, theme: theme, tone: tone) { ui.showSettings = false }
        }
    }
}
