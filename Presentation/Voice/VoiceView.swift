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
            .navigationTitle("Как сказать")
            .settingsTrigger()
            .sheet(isPresented: $model.showMicPriming) { primingSheet }
        }
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(spacing: Tokens.Space.s16) {
            GlassField("Что хотите сказать по-русски?", text: $model.intent) {
                fieldFocused = false
                model.submit()
            }
            .focused($fieldFocused)

            if showsMic {
                VStack(spacing: Tokens.Space.s8) {
                    MicButton(status: micStatus) {
                        fieldFocused = false
                        model.micTapped()
                    }
                    .accessibilityLabel("Микрофон")
                    .accessibilityValue(model.isListening ? "Слушаю" : "Готов")
                    .accessibilityHint(model.isListening ? "Коснитесь, чтобы остановить" : "Коснитесь, чтобы говорить по-русски")

                    Text(micCaption)
                        .textStyle(Tokens.Text.footnote)
                        .foregroundStyle(Tokens.Content.tertiary)
                }
            }

            if model.canSubmit && !model.isListening {
                EHButton("Подобрать варианты", icon: "sparkles", kind: .primary, fillWidth: true) {
                    fieldFocused = false
                    model.submit()
                }
            }
        }
    }

    private var micCaption: String {
        switch model.micStatus {
        case .listening: "Слушаю… коснитесь, чтобы остановить"
        case .processing: "Минуту…"
        case .idle: "Нажмите и говорите по-русски"
        }
    }

    // MARK: Content (state machine)

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .idle:
            if model.intent.isEmpty {
                StatusView(
                    systemImage: "text.bubble",
                    title: "Как сказать это по-английски?",
                    message: showsMic
                        ? "Спросите голосом или введите фразу по-русски — подберу три варианта с разной вежливостью."
                        : "Введите фразу по-русски — подберу три варианта с разной вежливостью."
                )
                .padding(.top, Tokens.Space.s24)
            }

        case .listening:
            EmptyView()

        case .processing:
            LoadingView("Подбираю варианты…")
                .padding(.top, Tokens.Space.s24)

        case .results:
            resultsSection

        case .failed:
            StatusView(
                systemImage: model.isOffline ? "wifi.slash" : "exclamationmark.triangle",
                title: model.isOffline ? "Нет соединения" : "Не получилось",
                message: model.errorMessage,
                actionTitle: model.canSubmit ? "Повторить" : nil,
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

            EHButton("Другие варианты", icon: "arrow.2.circlepath", kind: .glass, fillWidth: true) {
                model.regenerate()
            }
            .padding(.top, Tokens.Space.s4)
        }
    }

    // MARK: Banners & sheets

    private var apiKeyBanner: some View {
        HStack(spacing: Tokens.Space.s12) {
            Image(systemName: "key.slash")
                .foregroundStyle(Tokens.Signal.warning)
            Text("Нет ключа Claude API — варианты не загрузятся. Добавьте ключ в Secrets.xcconfig.")
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
            Text("Доступ к микрофону")
                .textStyle(Tokens.Text.title2)
                .foregroundStyle(Tokens.Content.primary)
            Text("Чтобы услышать ваш вопрос по-русски и подобрать английские фразы, приложению нужен микрофон. Запись не сохраняется.")
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.s24)
            Spacer()
            VStack(spacing: Tokens.Space.s8) {
                EHButton("Разрешить", kind: .primary, fillWidth: true) { model.confirmPriming() }
                EHButton("Не сейчас", kind: .ghost, fillWidth: true) { model.cancelPriming() }
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
