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
    @State private var onboarding = OnboardingStore()
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
        Group {
            if onboarding.isComplete {
                TabView(selection: $selection) {
                    Tab(Loc.t("Изучаю", "Study"), systemImage: "rectangle.stack", value: "library") {
                        StudyListView(model: library)
                    }
                    Tab(Loc.t("Смотреть", "See it"), systemImage: "camera", value: "camera") {
                        PhotoTranslateView(model: photo)
                    }
                    Tab(Loc.t("Сказать", "Say it"), systemImage: "mic.fill", value: "out") {
                        VoiceView(model: out)
                    }
                    Tab(Loc.t("Понять", "Get it"), systemImage: "character.bubble", value: "in") {
                        InView(model: inbound)
                    }
                    Tab(Loc.t("История", "History"), systemImage: "clock.arrow.circlepath", value: "history") {
                        HistoryView(model: history)
                    }
                }
                // Rebuild ONLY the tab content when the interface language changes — re-running every
                // screen's `Loc.t(...)`. Scoped here (not the whole body) so the Settings sheet and
                // `@State` survive: switching language live keeps the sheet open instead of dismissing.
                .id(language.language)
                .environment(ui)
                .environment(\.locale, language.locale)
                // "Explain" from See it / History: switch to Get it and run it in Explain mode.
                .onChange(of: ui.pendingExplain) { _, request in
                    guard let request else { return }
                    selection = "in"
                    inbound.startExplain(text: request.text, image: request.imageData)
                    ui.pendingExplain = nil
                }
                .sheet(isPresented: $ui.showSettings) {
                    SettingsView(model: settings, theme: theme, language: language, studied: studied, target: target) {
                        ui.showSettings = false
                    }
                    .environment(\.locale, language.locale)
                }
            } else {
                // First launch: pick languages before the app opens. Starts in the system language
                // (or English) via `LanguageStore.effective`; `.id` re-renders it live on change.
                OnboardingView(language: language, studied: studied, target: target) {
                    // Lock in all three choices (even if left at the system defaults), then dismiss.
                    UserDefaults.standard.set(language.language.rawValue, forKey: AppLanguage.storageKey)
                    UserDefaults.standard.set(studied.language.rawValue, forKey: StudiedLanguage.storageKey)
                    UserDefaults.standard.set(target.language.rawValue, forKey: TargetLanguage.storageKey)
                    onboarding.complete()
                }
                .id(language.language)
                .environment(\.locale, language.locale)
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }
}
