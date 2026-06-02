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
            .settingsTrigger()
            .sheet(isPresented: $model.showCameraPriming) { primingSheet }
            .fullScreenCover(isPresented: $model.presentCamera) {
                CameraPicker(onImage: { model.didCapture(prepareImageData($0) ?? $0) },
                             onCancel: { model.cameraCancelled() })
                    .ignoresSafeArea()
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let prepared = prepareImageData(data) {
                        model.didPickFromLibrary(prepared)
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
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            }
            ForEach(model.blocks) { block in
                blockCard(block)
            }
            EHButton("Другое фото", icon: "arrow.triangle.2.circlepath", kind: .glass, fillWidth: true) {
                model.reset()
            }
        }
    }

    /// One recognized block: English + Russian translation, with play + save.
    private func blockCard(_ block: TranslatedBlock) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            HStack(alignment: .top) {
                Text(block.en)
                    .textStyle(Tokens.Text.title3)
                    .foregroundStyle(Tokens.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tokens.Space.s8)
                Button { model.toggleSave(block) } label: {
                    Image(systemName: model.isSaved(block) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(model.isSaved(block) ? Tokens.Content.primary : Tokens.Content.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isSaved(block) ? "Убрать из изучаемого" : "Сохранить в изучаемое")
            }

            Rectangle().fill(Tokens.Hairline.default).frame(height: Tokens.Hairline.width)

            Text(block.ru)
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { model.play(block) } label: {
                Label(
                    model.isPlaying(block) ? "Озвучивается…" : "Озвучить",
                    systemImage: model.isPlaying(block) ? "speaker.wave.2.fill" : "speaker.wave.2"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Content.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Озвучить английский")
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

    /// Downscale (max 1536px) and re-encode to JPEG: keeps the upload small and a format Claude accepts.
    private func prepareImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1536
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rendered: UIImage = scale < 1
            ? UIGraphicsImageRenderer(size: target).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
              }
            : image
        return rendered.jpegData(compressionQuality: 0.8)
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
