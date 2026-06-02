//
//  TranslateView.swift
//  EnglishHelper — Presentation
//
//  "Перевод" screen. Typed English → single Russian translation; play the English source; save.
//

import SwiftUI
import DesignSystem

public struct TranslateView: View {
    @State private var model: TranslateViewModel
    @FocusState private var focused: Bool

    public init(model: TranslateViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        if model.needsAPIKey { apiKeyBanner }

                        GlassField("Текст на английском", text: $model.sourceText) {
                            focused = false
                            model.submit()
                        }
                        .focused($focused)

                        if model.canSubmit {
                            EHButton("Перевести", icon: "arrow.right", kind: .primary, fillWidth: true) {
                                focused = false
                                model.submit()
                            }
                        }

                        contentSection
                    }
                    .padding(Tokens.Space.s20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Перевод")
        }
    }

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .idle:
            if model.sourceText.isEmpty {
                StatusView(
                    systemImage: "character.bubble",
                    title: "Перевод с английского",
                    message: "Введите английский текст — переведу на русский, озвучу оригинал и сохраню в изучаемое."
                )
                .padding(.top, Tokens.Space.s24)
            }
        case .processing:
            LoadingView("Перевожу…").padding(.top, Tokens.Space.s24)
        case .result:
            resultCard
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

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            Text(model.translation)
                .textStyle(Tokens.Text.title3)
                .foregroundStyle(Tokens.Content.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Перевод: \(model.translation)")

            Rectangle()
                .fill(Tokens.Hairline.default)
                .frame(height: Tokens.Hairline.width)

            HStack(spacing: Tokens.Space.s12) {
                Button(action: model.playSource) {
                    HStack(spacing: Tokens.Space.s8) {
                        Image(systemName: model.isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .symbolEffect(.variableColor.iterative, isActive: model.isPlaying)
                        Text("Оригинал")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Озвучить английский оригинал")

                Spacer()

                Button(action: model.toggleSave) {
                    Image(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(model.isSaved ? Tokens.Content.primary : Tokens.Content.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isSaved ? "Убрать из изучаемого" : "Сохранить в изучаемое")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    private var apiKeyBanner: some View {
        HStack(spacing: Tokens.Space.s12) {
            Image(systemName: "key.slash").foregroundStyle(Tokens.Signal.warning)
            Text("Нет ключа Claude API — перевод не загрузится. Добавьте ключ в Secrets.xcconfig.")
                .textStyle(Tokens.Text.footnote)
                .foregroundStyle(Tokens.Content.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s12)
        .glassPanel(cornerRadius: Tokens.Radius.control)
    }
}
