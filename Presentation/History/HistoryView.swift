//
//  HistoryView.swift
//  EnglishHelper — Presentation
//
//  "История" — read-only log. Tap a row to review the full result.
//

import SwiftUI
import Foundation
import Domain
import DesignSystem

public struct HistoryView: View {
    @State private var model: HistoryViewModel

    public init(model: HistoryViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                contentSection
            }
            .navigationTitle(Loc.t("История", "History"))
            .settingsTrigger()
            .navigationDestination(for: HistoryEntry.self) { entry in
                HistoryDetailView(model: model.makeDetailViewModel(for: entry))
            }
            .task { await model.load() }
        }
    }

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .loading:
            LoadingView(Loc.t("Загружаю…", "Loading…"))
        case .failed:
            StatusView(systemImage: "exclamationmark.triangle", title: Loc.t("Не удалось загрузить", "Couldn't load"),
                       message: model.errorMessage,
                       actionTitle: Loc.t("Повторить", "Retry"), action: { Task { await model.load() } })
        case .empty:
            StatusView(systemImage: "clock.arrow.circlepath", title: Loc.t("История пуста", "No history yet"),
                       message: Loc.t("Здесь появятся ваши запросы: «Как сказать», переводы и фото-переводы.",
                                      "Your requests will appear here: how-to-say, translations, and photo translations."))
        case .loaded:
            List {
                ForEach(model.entries) { entry in
                    NavigationLink(value: entry) { HistoryRow(entry: entry) }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.s4, leading: Tokens.Space.s16,
                                                  bottom: Tokens.Space.s4, trailing: Tokens.Space.s16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: Tokens.Space.s12) {
            Image(systemName: kindIcon(entry.kind))
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Tokens.Content.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                Text(kindTitle(entry.kind))
                    .textStyle(Tokens.Text.caption2)
                    .foregroundStyle(Tokens.Content.tertiary)
                Text(entry.inputText)
                    .textStyle(Tokens.Text.headline)
                    .foregroundStyle(Tokens.Content.primary)
                    .lineLimit(1)
                Text(resultSnippet(entry.result))
                    .textStyle(Tokens.Text.subhead)
                    .foregroundStyle(Tokens.Content.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Tokens.Space.s8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Content.quaternary)
        }
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kindTitle(entry.kind)). \(entry.inputText)")
        .accessibilityHint(Loc.t("Открыть результат", "Open result"))
    }
}

// MARK: - Detail (read-only)

private struct HistoryDetailView: View {
    @State private var model: HistoryDetailViewModel

    init(model: HistoryDetailViewModel) {
        _model = State(initialValue: model)
    }

    private var entry: HistoryEntry { model.entry }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s16) {
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .textStyle(Tokens.Text.footnote)
                    .foregroundStyle(Tokens.Content.tertiary)

                labeledCard(title: Loc.t("Запрос", "Request")) {
                    Text(entry.inputText)
                        .textStyle(Tokens.Text.body)
                        .foregroundStyle(Tokens.Content.primary)
                }

                resultSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.s20)
        }
        .background(ScreenBackground())
        .navigationTitle(kindTitle(entry.kind))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadSavedState() }
        .alert(Loc.t("Изучаемое", "Study list"), isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder private var resultSection: some View {
        switch entry.result {
        case .howToSay(let variants):
            VStack(spacing: Tokens.Space.s12) {
                ForEach(variants) { variant in
                    // Same card as the Voice screen: tap = play, bookmark = save.
                    PhraseVariantCard(
                        english: variant.en,
                        register: registerLevel(variant.register),
                        contextRU: variant.contextRU,
                        isSaved: model.isSaved(HistoryDetailViewModel.variantKey(variant)),
                        isPlaying: model.isPlaying(HistoryDetailViewModel.variantKey(variant)),
                        onPlay: { model.playVariant(variant) },
                        onToggleSave: { model.toggleSaveVariant(variant) }
                    )
                }
            }
        case .translate(let ru), .photoTranslate(let ru):
            VStack(alignment: .leading, spacing: Tokens.Space.s12) {
                HStack {
                    sectionTitle(Loc.t("Перевод", "Translation"))
                    Spacer()
                    bookmark(isSaved: model.isSaved(HistoryDetailViewModel.translationKey)) {
                        model.toggleSaveTranslation()
                    }
                }
                Text(ru)
                    .textStyle(Tokens.Text.title3)
                    .foregroundStyle(Tokens.Content.primary)

                Button(action: model.playTranslationSource) {
                    Label(
                        model.isPlaying(HistoryDetailViewModel.translationKey) ? Loc.t("Озвучивается…", "Playing…") : Loc.t("Озвучить оригинал", "Play original"),
                        systemImage: model.isPlaying(HistoryDetailViewModel.translationKey) ? "speaker.wave.2.fill" : "speaker.wave.2"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Loc.t("Озвучить английский оригинал", "Play the English original"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.s16)
            .glassPanel(cornerRadius: Tokens.Radius.card)
        }
    }

    private func bookmark(isSaved: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isSaved ? Tokens.Content.primary : Tokens.Content.tertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? Loc.t("Убрать из изучаемого", "Remove from study list") : Loc.t("Сохранить в изучаемое", "Save to study list"))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .textStyle(Tokens.Text.caption2)
            .foregroundStyle(Tokens.Content.tertiary)
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.clearError() } })
    }

    private func labeledCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s8) {
            sectionTitle(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }
}

// MARK: - Shared helpers

private func kindIcon(_ kind: RequestKind) -> String {
    switch kind {
    case .howToSay: "quote.bubble"
    case .translate: "character.bubble"
    case .photoTranslate: "camera"
    }
}

private func kindTitle(_ kind: RequestKind) -> String {
    switch kind {
    case .howToSay: Loc.t("Как сказать", "How to say")
    case .translate: Loc.t("Перевод", "Translation")
    case .photoTranslate: Loc.t("Фото-перевод", "Photo translation")
    }
}

private func resultSnippet(_ result: RequestResult) -> String {
    switch result {
    case .howToSay(let variants): variants.first?.en ?? "—"
    case .translate(let ru): ru
    case .photoTranslate(let ru): ru
    }
}

private func registerLevel(_ register: Register) -> RegisterLevel {
    switch register {
    case .formal: .formal
    case .casual, .neutral: .casual
    case .slang: .slang
    }
}
