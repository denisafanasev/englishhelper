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
    @State private var translateModel = TranslateModelStore()
    @State private var explainModel = ExplainModelStore()
    @State private var sayItModel = SayItModelStore()
    @State private var ui = AppUIState()
    @State private var onboarding = OnboardingStore()
    @State private var network: NetworkMonitor
    @State private var selection = "out"
    @Environment(\.scenePhase) private var scenePhase

    /// True when persistence fell back to an in-memory store — changes this session won't be saved.
    private let degradedStorage: Bool
    /// Pulls the next item shared INTO the app via the iOS Share sheet (App-Group backed), or nil.
    /// Injected by the App composition root, which owns the App-Group reader. Default: nothing shared.
    private let consumeShared: () -> SharedRoute?

    public init(
        out: VoiceViewModel,
        inbound: InViewModel,
        photo: PhotoTranslateViewModel,
        library: StudyListViewModel,
        history: HistoryViewModel,
        settings: SettingsViewModel,
        degradedStorage: Bool = false,
        network: NetworkMonitor = NetworkMonitor(),
        consumeShared: @escaping () -> SharedRoute? = { nil }
    ) {
        _out = State(initialValue: out)
        _inbound = State(initialValue: inbound)
        _photo = State(initialValue: photo)
        _library = State(initialValue: library)
        _history = State(initialValue: history)
        _settings = State(initialValue: settings)
        self.degradedStorage = degradedStorage
        _network = State(initialValue: network)
        self.consumeShared = consumeShared
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
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 0) {
                        if !network.isOnline { offlineBanner }
                        if degradedStorage { degradedStorageBanner }
                    }
                }
                // Auto-retry on reconnect: when the link returns, replay whatever failed offline — each
                // view model no-ops unless it's actually sitting on an offline failure. Zero taps.
                .onChange(of: network.isOnline) { wasOnline, isOnline in
                    guard isOnline, !wasOnline else { return }
                    out.retryOnReconnect()
                    inbound.retryOnReconnect()
                    photo.retryOnReconnect()
                }
                // iOS Share sheet → scenario. The extension wakes us via the `englishhelper://` scheme;
                // becoming active is the fallback if that launch was blocked. Single-consume either way.
                .onOpenURL { url in
                    if url.scheme == "englishhelper" { handleShared() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { handleShared() }   // warm foreground (already-running app)
                }
                .task { handleShared() }                     // cold launch (onChange won't fire for the initial active state)
                // Rebuild ONLY the tab content when the interface language changes — re-running every
                // screen's `Loc.t(...)`. Scoped here (not the whole body) so the Settings sheet and
                // `@State` survive: switching language live keeps the sheet open instead of dismissing.
                // TRADE-OFF: this discards transient view-local @State inside the tabs (e.g. a half-built
                // export share) — acceptable since changing language mid-action is rare and deliberate.
                .id(language.language)
                .environment(ui)
                .environment(\.locale, language.locale)
                // "Explain" from See it / History: switch to Get it and run it in Explain mode.
                .onChange(of: ui.pendingExplain) { _, request in
                    guard let request else { return }
                    selection = "in"
                    inbound.startExplain(text: request.text, alternatives: request.alternatives)
                    ui.pendingExplain = nil
                }
                .sheet(isPresented: $ui.showSettings) {
                    SettingsView(model: settings, theme: theme, language: language, studied: studied,
                                 target: target, translateModel: translateModel, explainModel: explainModel,
                                 sayItModel: sayItModel) {
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

    /// Consume a pending shared item (from the Share Extension) and route it to its scenario:
    /// text → Get it / Explain, image → See it / Explain. No-ops when nothing is pending.
    private func handleShared() {
        guard let route = consumeShared() else { return }
        switch route {
        case .explainText(let text):
            selection = "in"
            inbound.startExplain(text: text)
        case .explainImage(let data):
            selection = "camera"
            photo.selectMode(.explain)
            photo.didPickFromLibrary(data)
        }
    }

    /// Shown whenever the device has no network path. A SOLID surface for legibility; it disappears
    /// the moment connectivity returns (which also triggers the auto-retry above).
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            Text(Loc.t(
                "Нет соединения — ждём сеть.",
                "No connection — waiting for the network.",
                "Pas de connexion — en attente du réseau.",
                "Sin conexión: esperando la red.",
                "Keine Verbindung – warte auf das Netzwerk.",
                "Nessuna connessione — in attesa della rete."))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }

    /// Shown when the on-disk store couldn't be opened: the app runs, but nothing saved this session
    /// will survive a relaunch. A SOLID surface (never glass under warning text) for legibility.
    private var degradedStorageBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(Loc.t(
                "Сохранённые данные недоступны. Изменения этой сессии не сохранятся.",
                "Saved data is unavailable. Changes this session won't be kept.",
                "Données enregistrées indisponibles. Les modifications de cette session ne seront pas conservées.",
                "Datos guardados no disponibles. Los cambios de esta sesión no se guardarán.",
                "Gespeicherte Daten nicht verfügbar. Änderungen dieser Sitzung werden nicht gespeichert.",
                "Dati salvati non disponibili. Le modifiche di questa sessione non verranno conservate."))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }
}
