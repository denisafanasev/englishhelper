//
//  SettingsView.swift
//  EnglishHelper — Presentation
//
//  Settings sheet: live API status, interface + target language, tone, theme, app info.
//

import SwiftUI
import DesignSystem

public struct SettingsView: View {
    @State private var model: SettingsViewModel
    private let theme: ThemeStore
    private let tone: ToneStore
    private let language: LanguageStore
    private let target: TargetLanguageStore
    private let onClose: () -> Void

    public init(
        model: SettingsViewModel,
        theme: ThemeStore,
        tone: ToneStore,
        language: LanguageStore,
        target: TargetLanguageStore,
        onClose: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.theme = theme
        self.tone = tone
        self.language = language
        self.target = target
        self.onClose = onClose
    }

    public var body: some View {
        @Bindable var theme = theme
        @Bindable var tone = tone
        @Bindable var language = language
        @Bindable var target = target
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        connectionCard
                        languageCard(language: $language.language)
                        targetCard(target: $target.language)
                        toneCard(tone: $tone.tone)
                        themeCard(theme: $theme.preference)
                        infoCard
                    }
                    .padding(Tokens.Space.s20)
                }
            }
            .navigationTitle(Loc.t("Настройки", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.t("Готово", "Done")) { onClose() }
                }
            }
            .task { await model.check() }
        }
    }

    // MARK: Connection

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("Подключение к Claude", "Claude connection"))
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
                    .accessibilityLabel(Loc.t("Проверить снова", "Check again"))
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
        case .checking: Loc.t("Проверяю…", "Checking…")
        case .ok: Loc.t("Подключено", "Connected")
        case .failed: Loc.t("Не удалось подключиться", "Couldn't connect")
        }
    }

    // MARK: Interface language

    private func languageCard(language: Binding<AppLanguage>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("Язык интерфейса", "Interface language"))
            Picker(Loc.t("Язык интерфейса", "Interface language"), selection: language) {
                ForEach(AppLanguage.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    // MARK: Target language ("In" translates to this)

    private func targetCard(target: Binding<TargetLanguage>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("Язык перевода (In)", "Translate to (In)"))
            Picker(Loc.t("Язык перевода", "Translate to"), selection: target) {
                ForEach(TargetLanguage.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    // MARK: Tone of voice

    private func toneCard(tone: Binding<ToneOfVoice>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("Тон фраз", "Phrase tone"))
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
            sectionTitle(Loc.t("Оформление", "Appearance"))
            Picker(Loc.t("Тема", "Theme"), selection: theme) {
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
            sectionTitle(Loc.t("О приложении", "About"))
            infoRow(Loc.t("Версия", "Version"), model.appVersion)
            Divider().overlay(Tokens.Hairline.default)
            infoRow(Loc.t("Модель", "Model"), model.modelName)
            Divider().overlay(Tokens.Hairline.default)
            infoRow(Loc.t("Голос озвучки", "Speech voice"), model.voiceLanguage)
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
