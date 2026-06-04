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
    @Environment(AppUIState.self) private var ui

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
            .navigationTitle(Loc.t("Фото-перевод", "See it"))
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
                    title: model.isOffline ? Loc.t("Нет соединения", "No connection") : Loc.t("Не получилось", "Something went wrong"),
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
                title: Loc.t("Переведите текст с фото", "Translate text from a photo"),
                message: Loc.t("Снимите вывеску, меню или страницу — распознаю английский и переведу на русский.",
                               "Snap a sign, menu, or page — I'll read the English and translate it.")
            )
            sourceButtons
        }
        .padding(.top, Tokens.Space.s24)
    }

    private var sourceButtons: some View {
        VStack(spacing: Tokens.Space.s12) {
            if CameraPicker.isAvailable {
                EHButton(Loc.t("Снять фото", "Take a photo"), icon: "camera", kind: .primary, fillWidth: true) {
                    model.cameraTapped()
                }
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                LibraryButtonLabel()
            }
            .accessibilityLabel(Loc.t("Выбрать фото из галереи", "Choose a photo from the library"))
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
                            LoadingView(Loc.t("Распознаю и перевожу…", "Reading and translating…"))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                    }
            } else {
                LoadingView(Loc.t("Распознаю и перевожу…", "Reading and translating…"))
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
            // Take or pick a NEW photo directly from the result (replaces the current one).
            sourceButtons
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
                .accessibilityLabel(model.isSaved(block)
                    ? Loc.t("Убрать из изучаемого", "Remove from study list")
                    : Loc.t("Сохранить в изучаемое", "Save to study list"))
            }

            Rectangle().fill(Tokens.Hairline.default).frame(height: Tokens.Hairline.width)

            Text(block.ru)
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Tokens.Space.s20) {
                Button { model.play(block) } label: {
                    Label(
                        model.isPlaying(block) ? Loc.t("Озвучивается…", "Playing…") : Loc.t("Озвучить", "Play"),
                        systemImage: model.isPlaying(block) ? "speaker.wave.2.fill" : "speaker.wave.2"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Loc.t("Озвучить", "Play"))

                // Copy the studied-language text (the card headline) to the clipboard.
                Button { UIPasteboard.general.string = block.en } label: {
                    Label(Loc.t("Скопировать", "Copy"), systemImage: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.Content.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Loc.t("Скопировать выражение", "Copy expression"))
            }

            // Explain THIS block — open Get it (Explain mode) with the block text + the photo as context.
            Button { ui.pendingExplain = ExplainRequest(text: block.en, imageData: model.imageData) } label: {
                Label(Loc.t("Объяснить", "Explain"), systemImage: "lightbulb")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Content.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Loc.t("Объяснить", "Explain"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    private var apiKeyBanner: some View {
        HStack(spacing: Tokens.Space.s12) {
            Image(systemName: "key.slash").foregroundStyle(Tokens.Signal.warning)
            Text(Loc.t("Нет ключа Claude API — перевод не загрузится. Добавьте ключ в Secrets.xcconfig.",
                       "No Claude API key — translation won't load. Add a key in Secrets.xcconfig."))
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
            Text(Loc.t("Доступ к камере", "Camera access"))
                .textStyle(Tokens.Text.title2)
                .foregroundStyle(Tokens.Content.primary)
            Text(Loc.t("Чтобы распознать английский текст на вывеске или в меню, приложению нужна камера. Фото никуда не отправляется без вашего действия.",
                       "To read English text on a sign or menu, the app needs the camera. Nothing is sent anywhere without your action."))
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.s24)
            Spacer()
            VStack(spacing: Tokens.Space.s8) {
                EHButton(Loc.t("Разрешить", "Allow"), kind: .primary, fillWidth: true) { model.confirmCameraPriming() }
                EHButton(Loc.t("Не сейчас", "Not now"), kind: .ghost, fillWidth: true) { model.cancelCameraPriming() }
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
            Text(Loc.t("Из галереи", "From library"))
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Tokens.Content.primary)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: Tokens.Radius.pill)
    }
}
