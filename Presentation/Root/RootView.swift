//
//  RootView.swift
//  EnglishHelper — Presentation
//
//  App shell: tab bar (Liquid Glass) + global theme + the Settings sheet.
//  Order: Изучаю · In · Out (center, default) · Камера · История.
//  "Out" (RU intent → 3 English variants, voice or text) and "In" (any language / English voice →
//  one translation into the target language) are the two translation directions.
//

import SwiftUI

public struct RootView: View {
    @State private var out: VoiceViewModel
    @State private var inbound: InViewModel
    @State private var photo: PhotoTranslateViewModel
    @State private var library: StudyListViewModel
    @State private var history: HistoryViewModel
    @State private var settings: SettingsViewModel

    @State private var theme = ThemeStore()
    @State private var tone = ToneStore()
    @State private var language = LanguageStore()
    @State private var target = TargetLanguageStore()
    @State private var ui = AppUIState()
    @State private var selection = "out"

    public init(
        out: VoiceViewModel,
        inbound: InViewModel,
        photo: PhotoTranslateViewModel,
        library: StudyListViewModel,
        history: HistoryViewModel,
        settings: SettingsViewModel
    ) {
        _out = State(initialValue: out)
        _inbound = State(initialValue: inbound)
        _photo = State(initialValue: photo)
        _library = State(initialValue: library)
        _history = State(initialValue: history)
        _settings = State(initialValue: settings)
    }

    public var body: some View {
        @Bindable var ui = ui
        TabView(selection: $selection) {
            Tab(Loc.t("Изучаю", "Study"), systemImage: "rectangle.stack", value: "library") {
                StudyListView(model: library)
            }
            Tab("In", systemImage: "character.bubble", value: "in") {
                InView(model: inbound)
            }
            Tab("Out", systemImage: "mic.fill", value: "out") {
                VoiceView(model: out)
            }
            Tab(Loc.t("Камера", "Camera"), systemImage: "camera", value: "camera") {
                PhotoTranslateView(model: photo)
            }
            Tab(Loc.t("История", "History"), systemImage: "clock.arrow.circlepath", value: "history") {
                HistoryView(model: history)
            }
        }
        .environment(ui)
        .environment(\.locale, language.locale)
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $ui.showSettings) {
            SettingsView(model: settings, theme: theme, tone: tone, language: language, target: target) {
                ui.showSettings = false
            }
        }
        .id(language.language)   // rebuild the shell when the interface language changes
    }
}
