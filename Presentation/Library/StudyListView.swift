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
            .navigationTitle("Изучаю")
            .settingsTrigger()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.export() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(model.expressions.isEmpty)
                        .accessibilityLabel("Экспортировать в AlgoApp")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showAddSheet = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Добавить выражение")
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
            .alert("Экспорт", isPresented: exportErrorBinding) {
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
            LoadingView("Загружаю…")
        case .failed:
            StatusView(systemImage: "exclamationmark.triangle", title: "Не удалось загрузить",
                       message: model.errorMessage,
                       actionTitle: "Повторить", action: { Task { await model.load() } })
        case .empty:
            StatusView(systemImage: "rectangle.stack", title: "Пока пусто",
                       message: "Сохраняйте фразы из «Голоса», «Перевода» или «Камеры» — или добавьте вручную.",
                       actionTitle: "Добавить", action: { model.showAddSheet = true })
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            ForEach(model.expressions) { expression in
                StudyRow(expression: expression)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Tokens.Space.s4, leading: Tokens.Space.s16,
                                              bottom: Tokens.Space.s4, trailing: Tokens.Space.s16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { model.delete(expression) } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { model.toggleLearned(expression) } label: {
                            Label(expression.learned ? "Не выучено" : "Выучено",
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
                            Text("Без ключа Claude API карточка сохранится без перевода и примеров.")
                                .textStyle(Tokens.Text.footnote)
                                .foregroundStyle(Tokens.Content.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GlassField("Английское выражение", text: $model.newEnglish)
                    GlassField("Контекст (необязательно)", text: $model.newContext)

                    if let addError = model.addError {
                        Text(addError)
                            .textStyle(Tokens.Text.footnote)
                            .foregroundStyle(Tokens.Signal.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if model.isAdding {
                        LoadingView("Дополняю переводом и примерами…")
                    } else {
                        EHButton("Сохранить", icon: "sparkles", kind: .primary, fillWidth: true) {
                            model.add()
                        }
                        .disabled(!model.canAdd)
                        .opacity(model.canAdd ? 1 : 0.5)
                    }
                }
                .padding(Tokens.Space.s20)
            }
            .background(Tokens.Surface.background)
            .navigationTitle("Новое выражение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { model.showAddSheet = false }
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
            if expression.learned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.Signal.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expression.en). \(expression.ru). \(expression.learned ? "Выучено" : "Не выучено")")
    }
}
