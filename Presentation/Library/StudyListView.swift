//
//  StudyListView.swift
//  EnglishHelper — Presentation
//
//  "Изучаю" — flat study list: add (enrich-then-store), swipe-delete, toggle learned, export .xml.
//

import SwiftUI
import Domain
import DesignSystem

public struct StudyListView: View {
    @State private var model: StudyListViewModel
    @State private var shareItem: ShareItem?

    public init(model: StudyListViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                contentSection
            }
            .navigationTitle(Loc.t("Изучаю", "Study"))
            .settingsTrigger()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(StudyListViewModel.ExportFormat.allCases, id: \.self) { format in
                            Button(format.title) { model.export(format) }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(model.expressions.isEmpty)
                    .accessibilityLabel(Loc.t("Экспортировать список", "Export list"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showAddSheet = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Loc.t("Добавить выражение", "Add expression"))
                }
            }
            .task { await model.load() }
            .sheet(isPresented: $model.showAddSheet) { addSheet }
            .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
            .onChange(of: model.exportedDeck) { _, deck in
                if let deck, let url = writeTemp(deck) {
                    shareItem = ShareItem(url: url)
                    model.clearExport()
                }
            }
            .alert(Loc.t("Экспорт", "Export"), isPresented: exportErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.exportError ?? "")
            }
        }
    }

    // MARK: Content

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .loading:
            LoadingView(Loc.t("Загружаю…", "Loading…"))
        case .failed:
            StatusView(systemImage: "exclamationmark.triangle", title: Loc.t("Не удалось загрузить", "Couldn't load"),
                       message: model.errorMessage,
                       actionTitle: Loc.t("Повторить", "Retry"), action: { Task { await model.load() } })
        case .empty:
            StatusView(systemImage: "rectangle.stack", title: Loc.t("Пока пусто", "Nothing yet"),
                       message: Loc.t("Сохраняйте фразы из «Скажи», «Пойми» или «Смотри» — или добавьте вручную.",
                                      "Save phrases from “Say”, “Understand”, or “Look” — or add them manually."),
                       actionTitle: Loc.t("Добавить", "Add"), action: { model.showAddSheet = true })
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            ForEach(model.expressions) { expression in
                StudyRow(expression: expression,
                         isPlaying: model.isPlaying(expression),
                         onPlay: { model.play(expression) })
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Tokens.Space.s4, leading: Tokens.Space.s16,
                                              bottom: Tokens.Space.s4, trailing: Tokens.Space.s16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { model.delete(expression) } label: {
                            Label(Loc.t("Удалить", "Delete"), systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { model.toggleLearned(expression) } label: {
                            Label(expression.learned ? Loc.t("Не выучено", "Not learned") : Loc.t("Выучено", "Learned"),
                                  systemImage: expression.learned ? "arrow.uturn.left" : "checkmark")
                        }
                        .tint(Tokens.Signal.success)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: Add sheet

    private var addSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.Space.s16) {
                    if model.needsAPIKey {
                        HStack(spacing: Tokens.Space.s8) {
                            Image(systemName: "key.slash").foregroundStyle(Tokens.Signal.warning)
                            Text(Loc.t("Без ключа Claude API карточка сохранится без перевода и примеров.",
                                       "Without a Claude API key, the card is saved without translation or examples."))
                                .textStyle(Tokens.Text.footnote)
                                .foregroundStyle(Tokens.Content.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GlassField(Loc.t("Английское выражение", "English expression"), text: $model.newEnglish)
                    GlassField(Loc.t("Контекст (необязательно)", "Context (optional)"), text: $model.newContext)

                    if let addError = model.addError {
                        Text(addError)
                            .textStyle(Tokens.Text.footnote)
                            .foregroundStyle(Tokens.Signal.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if model.isAdding {
                        LoadingView(Loc.t("Дополняю переводом и примерами…", "Adding translation and examples…"))
                    } else {
                        EHButton(Loc.t("Сохранить", "Save"), icon: "sparkles", kind: .primary, fillWidth: true) {
                            model.add()
                        }
                        .disabled(!model.canAdd)
                        .opacity(model.canAdd ? 1 : 0.5)
                    }
                }
                .padding(Tokens.Space.s20)
            }
            .background(Tokens.Surface.background)
            .navigationTitle(Loc.t("Новое выражение", "New expression"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Loc.t("Отмена", "Cancel")) { model.showAddSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Helpers

    private var exportErrorBinding: Binding<Bool> {
        Binding(get: { model.exportError != nil }, set: { if !$0 { model.clearExportError() } })
    }

    private func writeTemp(_ deck: ExportedDeck) -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: deck.filename)
        do {
            try deck.data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct StudyRow: View {
    let expression: Domain.Expression
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s12) {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                Text(expression.en)
                    .textStyle(Tokens.Text.headline)
                    .foregroundStyle(Tokens.Content.primary)
                    .strikethrough(expression.learned, color: Tokens.Content.tertiary)
                if !expression.ru.isEmpty {
                    Text(expression.ru)
                        .textStyle(Tokens.Text.subhead)
                        .foregroundStyle(Tokens.Content.secondary)
                }
                if !expression.synonyms.isEmpty {
                    Text(expression.synonyms.joined(separator: " · "))
                        .textStyle(Tokens.Text.footnote)
                        .foregroundStyle(Tokens.Content.tertiary)
                }
            }
            Spacer(minLength: Tokens.Space.s8)
            VStack(alignment: .trailing, spacing: Tokens.Space.s8) {
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Loc.t("Озвучить", "Play"))
                if expression.learned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Tokens.Signal.success)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expression.en). \(expression.ru). \(expression.learned ? Loc.t("Выучено", "Learned") : Loc.t("Не выучено", "Not learned"))")
        .accessibilityAction(named: Loc.t("Озвучить", "Play")) { onPlay() }
    }
}
