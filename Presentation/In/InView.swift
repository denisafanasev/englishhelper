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
        }
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(spacing: Tokens.Space.s16) {
            GlassField(Loc.t("Текст на любом языке", "Text in any language"), text: $model.source) {
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
                    : Loc.t("Коснитесь, чтобы говорить по-английски", "Tap to speak English"))

                Text(micCaption)
                    .textStyle(Tokens.Text.footnote)
                    .foregroundStyle(Tokens.Content.tertiary)
            }

            EHButton(actionTitle, icon: actionIcon, kind: .primary, fillWidth: true) {
                fieldFocused = false
                model.submit()
            }
            .disabled(!canTranslate)
            .opacity(canTranslate ? 1 : 0.5)

            SegmentedSelector(
                InViewModel.Mode.allCases,
                selected: model.mode,
                label: { $0.title },
                onSelect: { model.selectMode($0) }
            )
            .accessibilityLabel(Loc.t("Режим", "Mode"))
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

    private var micCaption: String {
        switch model.micStatus {
        case .listening: Loc.t("Слушаю… коснитесь, чтобы остановить", "Listening… tap to stop")
        case .processing: Loc.t("Минуту…", "One moment…")
        case .idle: Loc.t("Нажмите и говорите по-английски", "Tap and speak English")
        }
    }

    // MARK: Content (state machine)

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .idle:
            if model.source.isEmpty {
                StatusView(
                    systemImage: "character.bubble",
                    title: Loc.t("Что это значит?", "What does it mean?"),
                    message: Loc.t(
                        "Введите или надиктуйте выражение. В режиме «Перевод» переведу его по смыслу; в режиме «Объяснение» расскажу, что оно значит, насколько формально или резко звучит и с чем это можно сравнить.",
                        "Type or dictate an expression. In Translate I'll render its meaning; in Explain I'll tell you what it means, how formal or blunt it sounds, and what it compares to.")
                )
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

    /// The translation (your language) on top — what you read to understand. The SOURCE phrase below
    /// is the study item: bookmark + play attach to it, so saving files what was translated, never
    /// the variant in your own language.
    private func translationCard(_ translation: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            Text(translation)
                .textStyle(Tokens.Text.title3)
                .foregroundStyle(Tokens.Content.primary)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(Tokens.Hairline.default).frame(height: Tokens.Hairline.width)

            HStack(alignment: .top) {
                Text(model.sourceText)
                    .textStyle(Tokens.Text.body)
                    .foregroundStyle(Tokens.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tokens.Space.s8)
                Button { model.toggleSave() } label: {
                    Image(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(model.isSaved ? Tokens.Content.primary : Tokens.Content.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isSaved
                    ? Loc.t("Убрать из изучаемого", "Remove from study list")
                    : Loc.t("Сохранить в изучаемое", "Save to study list"))
            }

            if !model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { model.play() } label: {
                    Label(
                        model.isPlaying ? Loc.t("Озвучивается…", "Playing…") : Loc.t("Озвучить оригинал", "Play original"),
                        systemImage: model.isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Loc.t("Озвучить оригинал", "Play original"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    /// Explain mode: the English source is the headline (the study item — bookmark + play attach to
    /// it), with the nuance broken out below in the native language.
    private func explanationCard(_ explanation: ExpressionExplanation) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s16) {
            HStack(alignment: .top) {
                Text(model.sourceText)
                    .textStyle(Tokens.Text.title3)
                    .foregroundStyle(Tokens.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tokens.Space.s8)
                Button { model.toggleSave() } label: {
                    Image(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(model.isSaved ? Tokens.Content.primary : Tokens.Content.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isSaved
                    ? Loc.t("Убрать из изучаемого", "Remove from study list")
                    : Loc.t("Сохранить в изучаемое", "Save to study list"))
            }

            if !model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { model.play() } label: {
                    Label(
                        model.isPlaying ? Loc.t("Озвучивается…", "Playing…") : Loc.t("Озвучить", "Play"),
                        systemImage: model.isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Loc.t("Озвучить оригинал", "Play original"))
            }

            Rectangle().fill(Tokens.Hairline.default).frame(height: Tokens.Hairline.width)

            explanationRow(Loc.t("Значение", "Meaning"), explanation.meaning)
            explanationRow(Loc.t("Тон и регистр", "Tone & register"), explanation.register)
            explanationRow(Loc.t("В контексте", "In context"), explanation.context)
            explanationRow(Loc.t("Аналогия", "Analogy"), explanation.analogy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    @ViewBuilder private func explanationRow(_ label: String, _ text: String) -> some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                Text(label.uppercased())
                    .textStyle(Tokens.Text.caption2)
                    .foregroundStyle(Tokens.Content.tertiary)
                Text(text)
                    .textStyle(Tokens.Text.body)
                    .foregroundStyle(Tokens.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                "Чтобы услышать вашу английскую речь и перевести её, приложению нужен микрофон. Запись не сохраняется.",
                "To hear your English speech and translate it, the app needs the microphone. Nothing is recorded."))
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
