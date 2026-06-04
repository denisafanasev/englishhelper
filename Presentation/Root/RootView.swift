//
//  RootView.swift
//  EnglishHelper — Presentation
//
//  App shell: tab bar (Liquid Glass) + global theme + the Settings sheet.
//  Order: Изучаю · Смотреть/See · Сказать/Say (center, default) · Понять/Get · История.
//  "Сказать"/Say it (RU intent → 3 English variants, voice or text) and "Понять"/Get it (translate
//  OR explain an English expression into the native language) are the two comprehension directions;
//  "Смотреть"/See it is the photo translator.
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
    @State private var language = LanguageStore()
    @State private var studied = StudiedLanguageStore()
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
            Tab(Loc.t("Смотреть", "See"), systemImage: "camera", value: "camera") {
                PhotoTranslateView(model: photo)
            }
            Tab(Loc.t("Сказать", "Say"), systemImage: "mic.fill", value: "out") {
                VoiceView(model: out)
            }
            Tab(Loc.t("Понять", "Get"), systemImage: "character.bubble", value: "in") {
                InView(model: inbound)
            }
            Tab(Loc.t("История", "History"), systemImage: "clock.arrow.circlepath", value: "history") {
                HistoryView(model: history)
            }
        }
        // Rebuild ONLY the tab content when the interface language changes — re-running every
        // screen's `Loc.t(...)`. Scoped to the TabView (not the whole body) so the Settings sheet
        // and `@State` survive: switching language live keeps the sheet open instead of dismissing it.
        .id(language.language)
        .environment(ui)
        .environment(\.locale, language.locale)
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $ui.showSettings) {
            SettingsView(model: settings, theme: theme, language: language, studied: studied, target: target) {
                ui.showSettings = false
            }
            .environment(\.locale, language.locale)
        }
    }
}
