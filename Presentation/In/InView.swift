//
//  InView.swift
//  EnglishHelper — Presentation
//
//  "In" screen. English voice OR typed text in any language → ONE translation into the configured
//  target language. States: idle / listening / processing / result / error / offline.
//

import SwiftUI
import Domain
import DesignSystem

public struct InView: View {
    @State private var model: InViewModel
    @FocusState private var fieldFocused: Bool

    public init(model: InViewModel) {
        _model = State(initialValue: model)
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
            .navigationTitle(Loc.t("Понять", "Get it"))
            .settingsTrigger()
            .sheet(isPresented: $model.showMicPriming) { primingSheet }
            .alert(Loc.t("Сохранение", "Saving"), isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.saveError ?? "")
            }
        }
    }

    /// Surface a background save failure regardless of `phase` (inline error UI is only in `.failed`).
    private var saveErrorBinding: Binding<Bool> {
        Binding(get: { model.saveError != nil }, set: { if !$0 { model.clearSaveError() } })
    }

    // MARK: Input

    private var inputSection: some View {
        // s12 spacing MUST match VoiceView's inputSection so the mode selector, field, mic, and caption
        // land at IDENTICAL positions on both screens — no jump when switching Say it ↔ Get it.
        VStack(spacing: Tokens.Space.s12) {
            // Mode at the TOP (mirrors "Say it": the Explain/Translate choice frames the interaction,
            // same as How-to-say/What-to-say there).
            SegmentedSelector(
                InViewModel.Mode.allCases,
                selected: model.mode,
                label: { $0.title },
                onSelect: { model.selectMode($0) }
            )
            .accessibilityLabel(Loc.t("Режим", "Mode"))

            GlassField(Loc.t("Текст на изучаемом языке", "Text in the language you're learning"), text: $model.source) {
                fieldFocused = false
                model.submit()
            }
            .focused($fieldFocused)

            VStack(spacing: Tokens.Space.s8) {
                MicButton(status: micStatus) {
                    fieldFocused = false
                    model.micTapped()
                }
                .accessibilityLabel(Loc.t("Микрофон", "Microphone"))
                .accessibilityValue(model.isListening ? Loc.t("Слушаю", "Listening") : Loc.t("Готов", "Ready"))
                .accessibilityHint(model.isListening
                    ? Loc.t("Коснитесь, чтобы остановить", "Tap to stop")
                    : Loc.t("Коснитесь, чтобы говорить на изучаемом языке", "Tap to speak the language you're learning"))

                Text(micCaption)
                    .textStyle(Tokens.Text.footnote)
                    .foregroundStyle(Tokens.Content.tertiary)
            }

            EHButton(actionTitle, icon: actionIcon, kind: .primary, fillWidth: true) {
                fieldFocused = false
                model.submit()
            }
            .disabled(!canTranslate)   // EHButton dims itself when disabled
        }
    }

    /// Enabled only with non-empty input and not mid-request/listening.
    private var canTranslate: Bool {
        model.canSubmit && model.phase != .processing && !model.isListening
    }

    private var actionTitle: String {
        model.mode == .explain ? Loc.t("Объяснить", "Explain") : Loc.t("Перевести", "Translate")
    }

    private var actionIcon: String {
        model.mode == .explain ? "lightbulb" : "character.book.closed"
    }

    // The empty-state hint adapts to the selected mode: Explain describes the nuance breakdown,
    // Translate describes a faithful translation.
    private var idleIcon: String {
        model.mode == .explain ? "lightbulb" : "character.book.closed"
    }

    private var idleTitle: String {
        model.mode == .explain
            ? Loc.t("Что это значит?", "What does it mean?",
                    "Qu'est-ce que ça veut dire ?", "¿Qué significa?",
                    "Was bedeutet das?", "Cosa significa?")
            : Loc.t("Нужен перевод?", "Need a translation?",
                    "Besoin d'une traduction ?", "¿Necesitas una traducción?",
                    "Brauchst du eine Übersetzung?", "Ti serve una traduzione?")
    }

    private var idleMessage: String {
        model.mode == .explain
            ? Loc.t(
                "Введите или надиктуйте фразу — объясню, что она означает в живой языковой среде: смысл и оттенок, насколько формально или резко звучит и с чем это можно сравнить.",
                "Type or dictate a phrase — I'll explain what it really means in real-world use: its sense and nuance, how formal or blunt it sounds, and what it compares to.",
                "Saisissez ou dictez une phrase — j'expliquerai ce qu'elle veut vraiment dire dans la langue vivante : son sens et sa nuance, son registre (formel ou direct) et à quoi la comparer.",
                "Escribe o dicta una frase — te explicaré qué significa de verdad en el uso real del idioma: su sentido y matiz, qué tan formal o brusca suena y con qué se puede comparar.",
                "Tippe oder diktiere eine Phrase – ich erkläre, was sie im echten Sprachgebrauch wirklich bedeutet: Sinn und Nuance, wie förmlich oder direkt sie klingt und womit sie vergleichbar ist.",
                "Scrivi o detta una frase: ti spiegherò cosa significa davvero nell'uso reale della lingua: senso e sfumatura, quanto suona formale o diretta e a cosa si può paragonare.")
            : Loc.t(
                "Введите или надиктуйте фразу — дам точный перевод по смыслу на изучаемый и родной язык.",
                "Type or dictate a phrase — I'll give a faithful translation in the language you're learning and your own.",
                "Saisissez ou dictez une phrase — j'en donnerai une traduction fidèle dans la langue que vous apprenez et dans la vôtre.",
                "Escribe o dicta una frase — daré una traducción fiel en el idioma que estás aprendiendo y en el tuyo.",
                "Tippe oder diktiere eine Phrase – ich gebe eine getreue Übersetzung in der Sprache, die du lernst, und in deiner eigenen.",
                "Scrivi o detta una frase: fornirò una traduzione fedele nella lingua che stai imparando e nella tua.")
    }

    private var micCaption: String {
        switch model.micStatus {
        case .listening: Loc.t("Слушаю… коснитесь, чтобы остановить", "Listening… tap to stop")
        case .processing: Loc.t("Минуту…", "One moment…")
        case .idle: Loc.t("Нажмите и говорите на изучаемом языке", "Tap and speak the language you're learning")
        }
    }

    // MARK: Content (state machine)

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .idle:
            if model.source.isEmpty {
                StatusView(systemImage: idleIcon, title: idleTitle, message: idleMessage)
                    .padding(.top, Tokens.Space.s24)
            }

        case .listening:
            EmptyView()

        case .processing:
            LoadingView(model.mode == .explain ? Loc.t("Объясняю…", "Explaining…") : Loc.t("Перевожу…", "Translating…"))
                .padding(.top, Tokens.Space.s24)

        case .result:
            resultSection

        case .failed:
            // No extra top padding: StatusView pads s24 internally; a second s24 pushed Retry under
            // the tab bar in the tallest (error + Retry) state. See VoiceView for the same fix.
            StatusView(
                systemImage: model.isOffline ? "wifi.slash" : "exclamationmark.triangle",
                title: model.isOffline ? Loc.t("Нет соединения", "No connection") : Loc.t("Не получилось", "Something went wrong"),
                message: model.errorMessage,
                actionTitle: model.canSubmit ? Loc.t("Повторить", "Retry") : nil,
                action: model.canSubmit ? { model.submit() } : nil
            )
        }
    }

    @ViewBuilder private var resultSection: some View {
        VStack(spacing: Tokens.Space.s16) {
            if let explanation = model.explanation {
                explanationCard(explanation)
            } else if let translation = model.translation {
                translationCard(translation)
            }
            EHButton(Loc.t("Новое выражение", "New phrase"),
                     icon: "arrow.triangle.2.circlepath", kind: .glass, fillWidth: true) {
                model.reset()
            }
        }
    }

    /// Translate mode: the studied-language rendering is the headline (play + bookmark + the saved
    /// study item); the native translation sits below as the "understanding" line.
    private func translationCard(_ translation: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            // Studied source + icon actions (Play · Copy · Save) in the header row, like the phrase cards.
            HStack(alignment: .top) {
                Text(model.sourceText)
                    .textStyle(Tokens.Text.headline)
                    .foregroundStyle(Tokens.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tokens.Space.s8)
                HStack(spacing: Tokens.Space.s16) {
                    if !model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button { model.play() } label: {
                            Image(systemName: model.isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: Tokens.Icon.cardAction, weight: .medium))
                                .symbolEffect(.variableColor.iterative, isActive: model.isPlaying)
                                .foregroundStyle(model.isPlaying ? Tokens.Content.primary : Tokens.Content.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Loc.t("Озвучить", "Play"))

                        Button { model.startExplain(text: model.sourceText, image: nil) } label: {
                            Image(systemName: "lightbulb")
                                .font(.system(size: Tokens.Icon.cardAction, weight: .medium))
                                .foregroundStyle(Tokens.Content.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Loc.t("Объяснить", "Explain"))

                        CopyButton(model.sourceText, style: .icon,
                                   accessibilityLabel: Loc.t("Скопировать выражение", "Copy expression"))
                    }
                    Button { model.toggleSave() } label: {
                        Image(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: Tokens.Icon.cardActionProminent, weight: .medium))
                            .foregroundStyle(model.isSaved ? Tokens.Content.primary : Tokens.Content.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.isSaved
                        ? Loc.t("Убрать из изучаемого", "Remove from study list")
                        : Loc.t("Сохранить в изучаемое", "Save to study list"))
                }
            }

            Rectangle().fill(Tokens.Hairline.default).frame(height: Tokens.Hairline.width)

            Text(translation)
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    /// Explain mode: the studied-language rendering is the headline (the study item — bookmark + play
    /// attach to it), with the nuance broken out below in the native language. Shared card.
    private func explanationCard(_ explanation: ExpressionExplanation) -> some View {
        ExplanationCardView(
            studied: model.sourceText,
            explanation: explanation,
            isPlaying: model.isPlaying,
            onPlay: { model.play() },
            isSaved: model.isSaved,
            onToggleSave: { model.toggleSave() }
        )
    }

    // MARK: Banners & sheets

    private var apiKeyBanner: some View {
        HStack(spacing: Tokens.Space.s12) {
            Image(systemName: "key.slash")
                .foregroundStyle(Tokens.Signal.warning)
            Text(Loc.t("Нет ключа Claude API — перевод не загрузится. Добавьте ключ в Secrets.xcconfig.",
                       "No Claude API key — translation won't load. Add a key in Secrets.xcconfig."))
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
            Text(Loc.t(
                "Чтобы услышать вашу речь и перевести её, приложению нужен микрофон. Запись не сохраняется.",
                "To hear your speech and translate it, the app needs the microphone. Nothing is recorded."))
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
}
