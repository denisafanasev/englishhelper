//
//  ShareViewController.swift
//  EnglishHelper — Share Extension
//
//  Runs WITHOUT a compose UI: on launch it grabs the shared image or text, writes it to the App Group
//  (`SharedInbox`), then posts a tappable local notification so the user can foreground EnglishHelper
//  (iOS bars an extension from launching its host app — the old `openURL:` hack is force-failed on
//  iOS 18+). The app consumes the App-Group payload on activation and routes it — image → See it /
//  Explain, text → Get it / Explain.
//

import UIKit
import UniformTypeIdentifiers
import UserNotifications

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in await handleShare() }   // UIKit (responder chain, openURL:) must be on main
    }

    private func handleShare() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap(\.attachments).flatMap { $0 } ?? []

        // Prefer an image; otherwise fall back to text, then a URL (stored as its string). `wroteImage`
        // is nil when nothing usable was shared (so we don't post a spurious notification).
        var wroteImage: Bool?
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }),
           let data = await loadImage(provider) {
            SharedInbox.write(.image(data), now: Date().timeIntervalSince1970)
            wroteImage = true
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }),
                  let text = await loadText(provider) {
            SharedInbox.write(.text(text), now: Date().timeIntervalSince1970)
            wroteImage = false
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }),
                  let url = await loadURL(provider) {
            SharedInbox.write(.text(url.absoluteString), now: Date().timeIntervalSince1970)
            wroteImage = false
        }

        if let isImage = wroteImage { await notifyHostApp(isImage: isImage) }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: Attachment loading

    private func loadImage(_ provider: NSItemProvider) async -> Data? {
        // Sources vend an image as raw Data, a UIImage, or a file URL — handle all three.
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil)
        else { return nil }
        if let data = item as? Data { return data }
        if let image = item as? UIImage { return image.jpegData(compressionQuality: 0.9) }
        if let url = item as? URL, let data = try? Data(contentsOf: url) { return data }
        return nil
    }

    private func loadText(_ provider: NSItemProvider) async -> String? {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil)
        else { return nil }
        if let string = item as? String { return string }
        if let data = item as? Data { return String(data: data, encoding: .utf8) }
        return nil
    }

    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil)
        return item as? URL
    }

    // MARK: Bring the host app forward

    /// iOS won't let an extension foreground its host app (the `openURL:` responder-chain hack is force-
    /// failed on iOS 18+). Apple's sanctioned alternative: post a local notification the user taps to
    /// open EnglishHelper, which then consumes the App-Group payload. Posts only if the app already holds
    /// notification permission (requested by the app on launch — an extension can't reliably request it);
    /// if not, the payload still waits in the App Group and is picked up next time the app is opened.
    private func notifyHostApp(isImage: Bool) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let copy = ShareNotification.text(isImage: isImage, language: SharedLanguage.current())
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: ShareNotification.requestIdentifier, content: content, trigger: nil)
        try? await center.add(request)
    }
}
