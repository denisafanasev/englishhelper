//
//  SettingsView.swift
//  EnglishHelper — Presentation
//
//  Settings sheet: live API connection status, theme toggle (persisted), app/voice info.
//

import SwiftUI
import DesignSystem

public struct SettingsView: View {
    @State private var model: SettingsViewModel
    private let theme: ThemeStore
    private let tone: ToneStore
    private let onClose: () -> Void

    public init(model: SettingsViewModel, theme: ThemeStore, tone: ToneStore, onClose: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.theme = theme
        self.tone = tone
        self.onClose = onClose
    }

    public var body: some View {
        @Bindable var theme = theme
        @Bindable var tone = tone
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        connectionCard
                        toneCard(tone: $tone.tone)
                        themeCard(theme: $theme.preference)
                        infoCard
                    }
                    .padding(Tokens.Space.s20)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { onClose() }
                }
            }
            .task { await model.check() }
        }
    }

    // MARK: Connection

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle("Подключение к Claude")
            HStack(spacing: Tokens.Space.s12) {
                statusIndicator
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .textStyle(Tokens.Text.headline)
                        .foregroundStyle(Tokens.Content.primary)
                    if case .failed(let reason) = model.health {
                        Text(reason)
                            .textStyle(Tokens.Text.footnote)
                            .foregroundStyle(Tokens.Content.secondary)
                    }
                }
                Spacer()
                if model.health != .checking {
                    Button { Task { await model.check() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tokens.Content.secondary)
                    .accessibilityLabel("Проверить снова")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    @ViewBuilder private var statusIndicator: some View {
        switch model.health {
        case .checking:
            ProgressView().controlSize(.small)
        case .ok:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.Signal.success)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Tokens.Signal.error)
        }
    }

    private var statusTitle: String {
        switch model.health {
        case .checking: "Проверяю…"
        case .ok: "Подключено"
        case .failed: "Не удалось подключиться"
        }
    }

    // MARK: Tone of voice

    private func toneCard(tone: Binding<ToneOfVoice>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle("Тон фраз")
            VStack(spacing: 0) {
                ForEach(Array(ToneOfVoice.allCases.enumerated()), id: \.element) { index, option in
                    Button { tone.wrappedValue = option } label: {
                        HStack {
                            Text(option.title)
                                .textStyle(Tokens.Text.body)
                                .foregroundStyle(Tokens.Content.primary)
                            Spacer()
                            if tone.wrappedValue == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Tokens.Content.primary)
                            }
                        }
                        .padding(.vertical, Tokens.Space.s12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tone.wrappedValue == option ? [.isButton, .isSelected] : .isButton)

                    if index < ToneOfVoice.allCases.count - 1 {
                        Rectangle().fill(Tokens.Hairline.default).frame(height: Tokens.Hairline.width)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    // MARK: Theme

    private func themeCard(theme: Binding<ThemePreference>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle("Оформление")
            Picker("Тема", selection: theme) {
                ForEach(ThemePreference.allCases, id: \.self) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle("О приложении")
            infoRow("Версия", model.appVersion)
            Divider().overlay(Tokens.Hairline.default)
            infoRow("Модель", model.modelName)
            Divider().overlay(Tokens.Hairline.default)
            infoRow("Голос озвучки", model.voiceLanguage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).textStyle(Tokens.Text.body).foregroundStyle(Tokens.Content.secondary)
            Spacer()
            Text(value).textStyle(Tokens.Text.body).foregroundStyle(Tokens.Content.primary)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .textStyle(Tokens.Text.caption2)
            .foregroundStyle(Tokens.Content.tertiary)
    }
}
