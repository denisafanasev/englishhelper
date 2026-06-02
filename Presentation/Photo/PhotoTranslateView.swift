//
//  PhotoTranslateView.swift
//  EnglishHelper — Presentation
//
//  "Фото-перевод". Pick from camera/library → OCR boxes over the photo → Russian translation on a
//  SOLID scrim (no glass under text, for AA contrast) → play source / save.
//

import SwiftUI
import UIKit
import PhotosUI
import Domain
import DesignSystem

public struct PhotoTranslateView: View {
    @State private var model: PhotoTranslateViewModel
    @State private var libraryItem: PhotosPickerItem?

    public init(model: PhotoTranslateViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        if model.needsAPIKey { apiKeyBanner }
                        contentSection
                    }
                    .padding(Tokens.Space.s20)
                }
            }
            .navigationTitle("Фото-перевод")
            .sheet(isPresented: $model.showCameraPriming) { primingSheet }
            .fullScreenCover(isPresented: $model.presentCamera) {
                CameraPicker(onImage: { model.didCapture($0) }, onCancel: { model.cameraCancelled() })
                    .ignoresSafeArea()
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        model.didPickFromLibrary(data)
                    }
                    libraryItem = nil
                }
            }
        }
    }

    @ViewBuilder private var contentSection: some View {
        switch model.phase {
        case .idle:
            idleSection
        case .processing:
            processingSection
        case .result:
            resultSection
        case .failed:
            VStack(spacing: Tokens.Space.s16) {
                StatusView(
                    systemImage: model.isOffline ? "wifi.slash" : "exclamationmark.triangle",
                    title: model.isOffline ? "Нет соединения" : "Не получилось",
                    message: model.errorMessage
                )
                sourceButtons
            }
            .padding(.top, Tokens.Space.s24)
        }
    }

    // MARK: Sections

    private var idleSection: some View {
        VStack(spacing: Tokens.Space.s20) {
            StatusView(
                systemImage: "camera.viewfinder",
                title: "Переведите текст с фото",
                message: "Снимите вывеску, меню или страницу — распознаю английский и переведу на русский."
            )
            sourceButtons
        }
        .padding(.top, Tokens.Space.s24)
    }

    private var sourceButtons: some View {
        VStack(spacing: Tokens.Space.s12) {
            if CameraPicker.isAvailable {
                EHButton("Снять фото", icon: "camera", kind: .primary, fillWidth: true) {
                    model.cameraTapped()
                }
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                LibraryButtonLabel()
            }
            .accessibilityLabel("Выбрать фото из галереи")
        }
    }

    private var processingSection: some View {
        VStack(spacing: Tokens.Space.s16) {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                    .overlay {
                        ZStack {
                            Tokens.Scrim.solid
                            LoadingView("Распознаю и перевожу…")
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                    }
            } else {
                LoadingView("Распознаю и перевожу…")
            }
        }
    }

    private var resultSection: some View {
        VStack(spacing: Tokens.Space.s16) {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                    .overlay { boxesOverlay }
                    .overlay(alignment: .bottom) { scrimPanel }
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            }
            EHButton("Другое фото", icon: "arrow.triangle.2.circlepath", kind: .glass, fillWidth: true) {
                model.reset()
            }
        }
    }

    private var boxesOverlay: some View {
        GeometryReader { geo in
            ForEach(model.blocks) { block in
                let box = block.boundingBox
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: box.width * geo.size.width, height: box.height * geo.size.height)
                    .position(
                        x: (box.x + box.width / 2) * geo.size.width,
                        y: (box.y + box.height / 2) * geo.size.height
                    )
            }
        }
        .accessibilityHidden(true)
    }

    /// Translation on a SOLID scrim — white text, never glass, so it stays legible over the photo.
    private var scrimPanel: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s8) {
            if let source = model.result?.recognizedText {
                Text(source)
                    .textStyle(Tokens.Text.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            Text(model.result?.ru ?? "")
                .textStyle(Tokens.Text.headline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Tokens.Space.s16) {
                Button(action: model.playSource) {
                    Label("Оригинал", systemImage: model.isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Озвучить английский оригинал")

                Spacer()

                Button(action: model.toggleSave) {
                    Image(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isSaved ? "Убрать из изучаемого" : "Сохранить в изучаемое")
            }
            .padding(.top, Tokens.Space.s4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .background(Tokens.Scrim.solid)
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

    private var primingSheet: some View {
        VStack(spacing: Tokens.Space.s16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(Tokens.Content.primary)
                .padding(.top, Tokens.Space.s32)
            Text("Доступ к камере")
                .textStyle(Tokens.Text.title2)
                .foregroundStyle(Tokens.Content.primary)
            Text("Чтобы распознать английский текст на вывеске или в меню, приложению нужна камера. Фото никуда не отправляется без вашего действия.")
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.s24)
            Spacer()
            VStack(spacing: Tokens.Space.s8) {
                EHButton("Разрешить", kind: .primary, fillWidth: true) { model.confirmCameraPriming() }
                EHButton("Не сейчас", kind: .ghost, fillWidth: true) { model.cancelCameraPriming() }
            }
            .padding(.horizontal, Tokens.Space.s20)
            .padding(.bottom, Tokens.Space.s24)
        }
        .frame(maxWidth: .infinity)
        .background(Tokens.Surface.background)
        .presentationDetents([.medium])
    }

    private var uiImage: UIImage? {
        model.imageData.flatMap(UIImage.init(data:))
    }
}

/// Glass-styled label for the library PhotosPicker (its own View so the @MainActor `glassPanel`
/// isn't called from the picker's nonisolated label closure).
private struct LibraryButtonLabel: View {
    var body: some View {
        HStack(spacing: Tokens.Space.s8) {
            Image(systemName: "photo.on.rectangle")
            Text("Из галереи")
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Tokens.Content.primary)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: Tokens.Radius.pill)
    }
}
