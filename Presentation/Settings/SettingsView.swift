//
//  SettingsView.swift
//  EnglishHelper — Presentation
//
//  Settings sheet: live API status, interface + native language, theme, app info.
//  (Phrase tone moved onto the "Сказать"/Say it screen.)
//

import SwiftUI
import DesignSystem

public struct SettingsView: View {
    @State private var model: SettingsViewModel
    private let theme: ThemeStore
    private let language: LanguageStore
    private let studied: StudiedLanguageStore
    private let target: TargetLanguageStore
    private let onClose: () -> Void

    public init(
        model: SettingsViewModel,
        theme: ThemeStore,
        language: LanguageStore,
        studied: StudiedLanguageStore,
        target: TargetLanguageStore,
        onClose: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.theme = theme
        self.language = language
        self.studied = studied
        self.target = target
        self.onClose = onClose
    }

    public var body: some View {
        @Bindable var theme = theme
        @Bindable var language = language
        @Bindable var studied = studied
        @Bindable var target = target
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        connectionCard
                        languageCard(language: $language.language)
                        studiedCard(studied: $studied.language)
                        targetCard(target: $target.language)
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
            // SegmentedSelector reads `selected:` as a VALUE (not just a binding), so this view
            // takes a real dependency on the interface language — tapping a segment re-runs the
            // whole sheet's `Loc.t(...)` immediately, switching the interface live.
            SegmentedSelector(
                AppLanguage.allCases,
                selected: language.wrappedValue,
                label: { $0.abbreviation },
                onSelect: { language.wrappedValue = $0 }
            )
            .accessibilityLabel(Loc.t("Язык интерфейса", "Interface language"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    // MARK: Studied language (the language being learned — card headlines + all speech use it)

    private func studiedCard(studied: Binding<StudiedLanguage>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("Изучаемый язык", "Studied language"))
            SegmentedSelector(
                StudiedLanguage.allCases,
                selected: studied.wrappedValue,
                label: { $0.abbreviation },
                onSelect: { studied.wrappedValue = $0 }
            )
            .accessibilityLabel(Loc.t("Изучаемый язык", "Studied language"))
            Text(Loc.t("Язык, который вы учите. На нём показываются фразы и работает озвучка.",
                       "The language you're learning. Phrases are shown in it and all speech uses it."))
                .textStyle(Tokens.Text.footnote)
                .foregroundStyle(Tokens.Content.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    // MARK: Native language (final translations + explanations are produced in this language)

    private func targetCard(target: Binding<TargetLanguage>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("Родной язык", "Native language"))
            SegmentedSelector(
                TargetLanguage.allCases,
                selected: target.wrappedValue,
                label: { $0.abbreviation },
                onSelect: { target.wrappedValue = $0 }
            )
            .accessibilityLabel(Loc.t("Родной язык", "Native language"))
            Text(Loc.t("Язык переводов и объяснений на экране «Понять».",
                       "The language of translations and explanations on the Get it screen."))
                .textStyle(Tokens.Text.footnote)
                .foregroundStyle(Tokens.Content.tertiary)
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
            infoRow(Loc.t("Голос озвучки", "Speech voice"), studied.language.title)
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
