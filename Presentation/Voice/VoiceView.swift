//
//  VoiceView.swift
//  EnglishHelper — Presentation
//
//  "Как сказать" screen. Voice OR typed Russian → 3 register-tagged English variants
//  (tap = play, bookmark = save). States: idle / listening / processing / results / error / offline.
//

import SwiftUI
import Domain
import DesignSystem

public struct VoiceView: View {
    @State private var model: VoiceViewModel
    @FocusState private var fieldFocused: Bool
    @Environment(AppUIState.self) private var ui   // for routing per-variant "explain" into Get it
    /// `false` for the text-only "Текст" tab (no microphone — same flow, typed input).
    private let showsMic: Bool

    public init(model: VoiceViewModel, showsMic: Bool = true) {
        _model = State(initialValue: model)
        self.showsMic = showsMic
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        if model.needsAPIKey { apiKeyBanner }
                        inputSection
                        contentSection
                    }
                    .padding(Tokens.Space.s20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            // Screen title matches the tab name ("Say it" / "Сказать") in every language.
            .navigationTitle(Loc.t("Сказать", "Say it"))
            .settingsTrigger()
            // Leaving the screen (tab switch) drops an input edit the user never submitted, so the
            // field still matches the on-screen results when they come back.
            .onDisappear { model.screenDisappeared() }
            .sheet(isPresented: $model.showMicPriming) { primingSheet }
            .alert(Loc.t("Сохранение", "Saving"), isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.saveError ?? "")
            }
        }
    }

    /// A background save failure is shown as an alert so it surfaces even while results are on screen
    /// (the inline error UI only renders in the `.failed` phase).
    private var saveErrorBinding: Binding<Bool> {
        Binding(get: { model.saveError != nil }, set: { if !$0 { model.clearSaveError() } })
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(spacing: Tokens.Space.s12) {   // a touch tighter so the empty-state hint clears the tab bar
            // Mode: phrasings of ONE thought ("how to say") vs the useful phrases for a SITUATION
            // ("what to say"). Placed up top so the choice frames the whole interaction.
            SegmentedSelector(
                VoiceViewModel.Mode.allCases,
                selected: model.mode,
                label: { $0.title },
                accessibilityID: "sayit.mode",
                onSelect: { model.selectMode($0) }
            )
            // `.contain` keeps each segment's OWN label (a bare container label would overwrite
            // every segment as "Mode", leaving VoiceOver users unable to tell the options apart).
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Loc.t("Режим", "Mode"))

            GlassField(fieldPrompt, text: $model.intent, accessibilityID: "sayit.input") {
                fieldFocused = false
                model.pick()
            }
            .focused($fieldFocused)

            if showsMic {
                VStack(spacing: Tokens.Space.s8) {
                    MicButton(status: micStatus) {
                        fieldFocused = false
                        model.micTapped()
                    }
                    .accessibilityLabel(Loc.t("Микрофон", "Microphone"))
                    .accessibilityValue(model.isListening ? Loc.t("Слушаю", "Listening") : Loc.t("Готов", "Ready"))
                    .accessibilityHint(model.isListening
                        ? Loc.t("Коснитесь, чтобы остановить", "Tap to stop")
                        : Loc.t("Коснитесь, чтобы говорить на родном языке", "Tap to speak your native language"))

                    Text(micCaption)
                        .textStyle(Tokens.Text.footnote)
                        .foregroundStyle(Tokens.Content.tertiary)
                }
            }

            EHButton(actionTitle, icon: actionIcon, kind: .primary, fillWidth: true,
                     accessibilityID: "sayit.action") {
                fieldFocused = false
                model.pick()
            }
            .disabled(!canPick)   // EHButton dims itself when disabled

            SegmentedSelector(
                ToneOfVoice.allCases,
                selected: model.tone,
                label: { $0.shortTitle },
                accessibilityID: "sayit.tone",
                onSelect: { model.selectTone($0) }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Loc.t("Тон фраз", "Phrase tone"))
        }
    }

    /// Enabled only with non-empty input and not mid-request/listening.
    private var canPick: Bool {
        model.canSubmit && model.phase != .processing && !model.isListening
    }

    private var micCaption: String {
        switch model.micStatus {
        case .listening: Loc.t("Слушаю… коснитесь, чтобы остановить", "Listening… tap to stop")
        case .processing: Loc.t("Минуту…", "One moment…")
        case .idle: Loc.t("Нажмите и говорите на родном языке", "Tap and speak your native language")
        }
    }

    // MARK: Mode-aware copy

    /// Field placeholder: a thought to phrase ("how to say") vs a situation to cover ("what to say").
    private var fieldPrompt: String {
        model.mode == .howToSay
            ? Loc.t("Что хотите сказать?", "What do you want to say?",
                    "Que voulez-vous dire ?", "¿Qué quieres decir?",
                    "Was möchtest du sagen?", "Cosa vuoi dire?")
            : Loc.t("Опишите ситуацию", "Describe the situation",
                    "Décrivez la situation", "Describe la situación",
                    "Beschreibe die Situation", "Descrivi la situazione")
    }

    /// With results already shown the button regenerates (`pick()` → `regenerate()`), so the label and
    /// icon must read "another set", not the first-run "find phrasings".
    private var actionTitle: String {
        if model.phase == .results {
            return Loc.t("Другие варианты", "Other options",
                         "Autres options", "Otras opciones", "Andere Optionen", "Altre opzioni")
        }
        return model.mode == .howToSay
            ? Loc.t("Подобрать варианты", "Find phrasings",
                    "Trouver des formulations", "Buscar formulaciones",
                    "Formulierungen finden", "Trova formulazioni")
            : Loc.t("Подобрать фразы", "Suggest phrases",
                    "Proposer des phrases", "Sugerir frases",
                    "Phrasen vorschlagen", "Suggerisci frasi")
    }

    private var actionIcon: String {
        model.phase == .results ? "arrow.triangle.2.circlepath" : "sparkles"
    }

    private var loadingText: String {
        model.mode == .howToSay
            ? Loc.t("Подбираю варианты…", "Finding phrasings…",
                    "Recherche de formulations…", "Buscando formulaciones…",
                    "Suche Formulierungen…", "Ricerca formulazioni…")
            : Loc.t("Подбираю фразы…", "Finding phrases…",
                    "Recherche de phrases…", "Buscando frases…",
                    "Suche Phrasen…", "Ricerca frasi…")
    }

    private var idleIcon: String {
        model.mode == .howToSay ? "text.bubble" : "bubble.left.and.bubble.right"
    }

    private var idleTitle: String {
        model.mode == .howToSay
            ? Loc.t("Как это сказать?", "How do you say it?",
                    "Comment le dire ?", "¿Cómo se dice?",
                    "Wie sagt man das?", "Come si dice?")
            : Loc.t("Что говорить?", "What should you say?",
                    "Quoi dire ?", "¿Qué decir?",
                    "Was solltest du sagen?", "Cosa dovresti dire?")
    }

    private var idleMessage: String {
        model.mode == .howToSay
            ? Loc.t(
                "Введите или произнесите фразу или мысль — подберу 3 варианта, как это сказать, в выбранном тоне.",
                "Type or say a phrase or thought — I'll offer 3 ways to say it in the chosen tone.",
                "Saisissez ou dites une phrase ou une idée — je proposerai 3 façons de le dire dans le ton choisi.",
                "Escribe o di una frase o idea — te ofreceré 3 formas de decirlo en el tono elegido.",
                "Tippe oder sprich eine Phrase oder einen Gedanken – ich biete 3 Möglichkeiten, es im gewählten Ton zu sagen.",
                "Scrivi o pronuncia una frase o un pensiero: ti offrirò 3 modi per dirlo nel tono scelto.")
            : Loc.t(
                "Опишите ситуацию (например «приём у врача») — подберу самые полезные фразы для неё в выбранном тоне.",
                "Describe a situation (e.g. a doctor's appointment) — I'll suggest the most useful phrases for it in the chosen tone.",
                "Décrivez une situation (par ex. un rendez-vous chez le médecin) — je proposerai les phrases les plus utiles, dans le ton choisi.",
                "Describe una situación (p. ej. una cita con el médico) — sugeriré las frases más útiles, en el tono elegido.",
                "Beschreibe eine Situation (z. B. einen Arzttermin) – ich schlage die nützlichsten Phrasen dafür im gewählten Ton vor.",
                "Descrivi una situazione (ad es. una visita dal medico): ti suggerirò le frasi più utili, nel tono scelto.")
    }

    // MARK: Content (state machine)

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .idle:
            if model.intent.isEmpty {
                StatusView(systemImage: idleIcon, title: idleTitle, message: idleMessage)
                    .padding(.top, Tokens.Space.s8)
            }

        case .listening:
            EmptyView()

        case .processing:
            LoadingView(loadingText)
                .padding(.top, Tokens.Space.s24)

        case .results:
            resultsSection

        case .failed:
            // No extra top padding: StatusView already pads s24 internally, and the failed block is
            // the tallest state (icon + message + Retry) — a second s24 pushed Retry under the tab bar.
            StatusView(
                systemImage: model.isOffline ? "wifi.slash" : "exclamationmark.triangle",
                title: model.isOffline ? Loc.t("Нет соединения", "No connection") : Loc.t("Не получилось", "Something went wrong"),
                message: model.errorMessage,
                actionTitle: model.canSubmit ? Loc.t("Повторить", "Retry") : nil,
                action: model.canSubmit ? { model.submit() } : nil
            )
        }
    }

    private var resultsSection: some View {
        VStack(spacing: Tokens.Space.s16) {
            ForEach(model.variants) { variant in
                PhraseVariantCard(
                    english: variant.en,
                    register: registerLevel(variant.register),
                    contextRU: variant.contextRU,
                    isSaved: model.isSaved(variant),
                    isPlaying: model.isPlaying(variant),
                    onPlay: { model.play(variant) },
                    onToggleSave: { model.toggleSave(variant) },
                    // "Why this one?" → route into the Explain engine for THIS phrasing, contrasted
                    // against the sibling variants. Reuses the same Explain flow as See it / History.
                    onExplain: {
                        let alternatives = model.variants
                            .filter { $0.id != variant.id }
                            .map(\.en)
                        ui.pendingExplain = ExplainRequest(text: variant.en, alternatives: alternatives)
                    }
                )
            }
        }
    }

    // MARK: Banners & sheets

    private var apiKeyBanner: some View {
        HStack(spacing: Tokens.Space.s12) {
            Image(systemName: "key.slash")
                .foregroundStyle(Tokens.Signal.warning)
            Text(Loc.t("Нет ключа Claude API — варианты не загрузятся. Добавьте ключ в Secrets.xcconfig.",
                       "No Claude API key — options won't load. Add a key in Secrets.xcconfig."))
                .textStyle(Tokens.Text.footnote)
                .foregroundStyle(Tokens.Content.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s12)
        .glassPanel(cornerRadius: Tokens.Radius.control)
    }

    private var primingSheet: some View {
        VStack(spacing: Tokens.Space.s16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(Tokens.Content.primary)
                .padding(.top, Tokens.Space.s32)
            Text(Loc.t("Доступ к микрофону", "Microphone access"))
                .textStyle(Tokens.Text.title2)
                .foregroundStyle(Tokens.Content.primary)
            Text(Loc.t("Чтобы услышать вас и подобрать фразы, приложению нужен микрофон. Запись не сохраняется.",
                       "To hear you and find phrasings, the app needs the microphone. Nothing is recorded."))
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.s24)
            Spacer()
            VStack(spacing: Tokens.Space.s8) {
                EHButton(Loc.t("Разрешить", "Allow"), kind: .primary, fillWidth: true) { model.confirmPriming() }
                EHButton(Loc.t("Не сейчас", "Not now"), kind: .ghost, fillWidth: true) { model.cancelPriming() }
            }
            .padding(.horizontal, Tokens.Space.s20)
            .padding(.bottom, Tokens.Space.s24)
        }
        .frame(maxWidth: .infinity)
        .background(Tokens.Surface.background)
        .presentationDetents([.medium])
    }

    // MARK: Mapping

    private var micStatus: MicButton.Status {
        switch model.micStatus {
        case .idle: .idle
        case .listening: .listening
        case .processing: .processing
        }
    }

    private func registerLevel(_ register: Register) -> RegisterLevel {
        switch register {
        case .formal: .formal
        case .casual, .neutral: .casual   // design styles 3 tiers; neutral → casual
        case .slang: .slang
        }
    }
}
