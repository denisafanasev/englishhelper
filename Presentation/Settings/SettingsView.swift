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
    @State private var showClearCacheConfirm = false
    private let theme: ThemeStore
    private let language: LanguageStore
    private let studied: StudiedLanguageStore
    private let target: TargetLanguageStore
    private let translateModel: TranslateModelStore
    private let explainModel: ExplainModelStore
    private let sayItModel: SayItModelStore
    private let onClose: () -> Void

    public init(
        model: SettingsViewModel,
        theme: ThemeStore,
        language: LanguageStore,
        studied: StudiedLanguageStore,
        target: TargetLanguageStore,
        translateModel: TranslateModelStore,
        explainModel: ExplainModelStore,
        sayItModel: SayItModelStore,
        onClose: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.theme = theme
        self.language = language
        self.studied = studied
        self.target = target
        self.translateModel = translateModel
        self.explainModel = explainModel
        self.sayItModel = sayItModel
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
                        modelsCard
                        languageCard(language: $language.language)
                        studiedCard(studied: $studied.language)
                        targetCard(target: $target.language)
                        themeCard(theme: $theme.preference)
                        cacheCard
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
            .task { await model.loadCacheStats() }
        }
    }

    // MARK: Connection

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            HStack {
                sectionTitle(Loc.t("Подключение к сервисам", "Service connections"))
                Spacer()
                // One re-check button covers every service (only once none is mid-check).
                if model.health != .checking, model.fastHealth != .checking, model.sonioxHealth != .checking {
                    Button { Task { await model.check() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tokens.Content.secondary)
                    .accessibilityLabel(Loc.t("Проверить снова", "Check again"))
                }
            }
            // Both Claude models the app routes to: standard (Sonnet, everything) + fast (Haiku,
            // plain translate) — then the Soniox real-time model (online translation), shown by
            // its model id exactly like the Claude rows.
            modelStatusRow(model.modelName, health: model.health)
            Divider().overlay(Tokens.Hairline.default)
            modelStatusRow(model.fastModelName, health: model.fastHealth)
            Divider().overlay(Tokens.Hairline.default)
            modelStatusRow("soniox · \(model.sonioxModelName)", health: model.sonioxHealth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    private func modelStatusRow(_ name: String, health: SettingsViewModel.Health) -> some View {
        HStack(spacing: Tokens.Space.s12) {
            statusIcon(health)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .textStyle(Tokens.Text.headline)
                    .foregroundStyle(Tokens.Content.primary)
                Text(statusLine(health))
                    .textStyle(Tokens.Text.footnote)
                    .foregroundStyle(Tokens.Content.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(statusLine(health))")
    }

    @ViewBuilder private func statusIcon(_ health: SettingsViewModel.Health) -> some View {
        switch health {
        case .checking:
            ProgressView().controlSize(.small)
        case .ok:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.Signal.success)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Tokens.Signal.error)
        }
    }

    private func statusLine(_ health: SettingsViewModel.Health) -> String {
        switch health {
        case .checking: Loc.t("Проверяю…", "Checking…")
        case .ok: Loc.t("Подключено", "Connected")
        case .failed(let reason): reason
        }
    }

    // MARK: Models per scenario

    private var modelsCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s16) {
            sectionTitle(Loc.t("Модели по сценарию", "Models by scenario"))
            modelPicker(
                title: Loc.t("Фразы (Сказать)", "Phrases (Say it)"),
                note: Loc.t("Экран «Сказать» — генерация вариантов.", "Say it — phrase generation."),
                choice: sayItModel.choice,
                onSelect: { sayItModel.choice = $0 }
            )
            Divider().overlay(Tokens.Hairline.default)
            modelPicker(
                title: Loc.t("Перевод", "Translate"),
                note: Loc.t("Экран «Понять» → Перевод.", "Get it → Translate."),
                choice: translateModel.choice,
                onSelect: { translateModel.choice = $0 }
            )
            Divider().overlay(Tokens.Hairline.default)
            modelPicker(
                title: Loc.t("Объяснение", "Explain"),
                note: Loc.t("Экран «Понять» → Объяснить (и все кнопки «объяснить»).",
                            "Get it → Explain (and every \"explain\" button)."),
                choice: explainModel.choice,
                onSelect: { explainModel.choice = $0 }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    private func modelPicker(title: String, note: String, choice: LLMModelChoice,
                             onSelect: @escaping (LLMModelChoice) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s8) {
            Text(title)
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.primary)
            SegmentedSelector(
                LLMModelChoice.allCases,
                selected: choice,
                label: { $0.title },
                onSelect: onSelect
            )
            .accessibilityLabel(title)
            Text(note)
                .textStyle(Tokens.Text.footnote)
                .foregroundStyle(Tokens.Content.tertiary)
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

    // MARK: Translation cache

    private var cacheCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("Кэш переводов", "Translation cache"))
            infoRow(Loc.t("В кэше", "Stored"), "\(model.cacheStats.entryCount)")
            Divider().overlay(Tokens.Hairline.default)
            infoRow(Loc.t("Взято из кэша", "Served from cache"), "\(model.cacheStats.hitCount)")
            Divider().overlay(Tokens.Hairline.default)
            Button { showClearCacheConfirm = true } label: {
                Text(Loc.t("Очистить кэш", "Clear cache"))
                    .textStyle(Tokens.Text.body)
                    .foregroundStyle(model.cacheStats.entryCount == 0 ? Tokens.Content.tertiary : Tokens.Signal.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(model.cacheStats.entryCount == 0)
            Text(Loc.t("Повторные переводы одного и того же текста берутся из кэша, а не из модели.",
                       "Repeat translations of the same text are served from the cache, not the model."))
                .textStyle(Tokens.Text.footnote)
                .foregroundStyle(Tokens.Content.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .confirmationDialog(
            Loc.t("Очистить кэш переводов?", "Clear the translation cache?"),
            isPresented: $showClearCacheConfirm, titleVisibility: .visible
        ) {
            Button(Loc.t("Очистить", "Clear"), role: .destructive) { Task { await model.clearCache() } }
            Button(Loc.t("Отмена", "Cancel"), role: .cancel) {}
        }
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            sectionTitle(Loc.t("О приложении", "About"))
            infoRow(Loc.t("Версия", "Version"), model.appVersion)
            Divider().overlay(Tokens.Hairline.default)
            infoRow(Loc.t("Модель", "Model"), model.modelName)
            Divider().overlay(Tokens.Hairline.default)
            infoRow(Loc.t("Быстрая модель", "Fast model"), model.fastModelName)
            Divider().overlay(Tokens.Hairline.default)
            infoRow(Loc.t("Модель распознавания", "Speech model"), model.sonioxModelName)
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
