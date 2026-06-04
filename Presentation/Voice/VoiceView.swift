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
            .navigationTitle(Loc.t("Как сказать", "Say it"))
            .settingsTrigger()
            .sheet(isPresented: $model.showMicPriming) { primingSheet }
        }
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(spacing: Tokens.Space.s16) {
            GlassField(Loc.t("Что хотите сказать?", "What do you want to say?"), text: $model.intent) {
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

            EHButton(Loc.t("Подобрать варианты", "Find phrasings"), icon: "sparkles", kind: .primary, fillWidth: true) {
                fieldFocused = false
                model.pick()
            }
            .disabled(!canPick)
            .opacity(canPick ? 1 : 0.5)

            SegmentedSelector(
                ToneOfVoice.allCases,
                selected: model.tone,
                label: { $0.shortTitle },
                onSelect: { model.selectTone($0) }
            )
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

    // MARK: Content (state machine)

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .idle:
            if model.intent.isEmpty {
                StatusView(
                    systemImage: "text.bubble",
                    title: Loc.t("Как это сказать?", "How do you say it?"),
                    message: showsMic
                        ? Loc.t("Спросите голосом или введите фразу — подберу три варианта с разной вежливостью.",
                                "Ask by voice or type a phrase — I'll offer three options at different politeness levels.")
                        : Loc.t("Введите фразу — подберу три варианта с разной вежливостью.",
                                "Type a phrase — I'll offer three options at different politeness levels.")
                )
                .padding(.top, Tokens.Space.s24)
            }

        case .listening:
            EmptyView()

        case .processing:
            LoadingView(Loc.t("Подбираю варианты…", "Finding phrasings…"))
                .padding(.top, Tokens.Space.s24)

        case .results:
            resultsSection

        case .failed:
            StatusView(
                systemImage: model.isOffline ? "wifi.slash" : "exclamationmark.triangle",
                title: model.isOffline ? Loc.t("Нет соединения", "No connection") : Loc.t("Не получилось", "Something went wrong"),
                message: model.errorMessage,
                actionTitle: model.canSubmit ? Loc.t("Повторить", "Retry") : nil,
                action: model.canSubmit ? { model.submit() } : nil
            )
            .padding(.top, Tokens.Space.s24)
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
                    onToggleSave: { model.toggleSave(variant) }
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
