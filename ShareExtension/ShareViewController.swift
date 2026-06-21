//
//  ShareViewController.swift
//  EnglishHelper — Share Extension
//
//  Runs WITHOUT a compose UI: on launch it grabs the shared image or text, writes it to the App Group
//  (`SharedInbox`), opens the host app via the `englishhelper://` scheme, and finishes. The app then
//  routes it — image → See it / Explain, text → Get it / Explain.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await handleShare() }
    }

    private func handleShare() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap(\.attachments).flatMap { $0 } ?? []

        // Prefer an image; otherwise fall back to text, then a URL (stored as its string).
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }),
           let data = await loadImage(provider) {
            SharedInbox.write(.image(data), now: Date().timeIntervalSince1970)
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }),
                  let text = await loadText(provider) {
            SharedInbox.write(.text(text), now: Date().timeIntervalSince1970)
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }),
                  let url = await loadURL(provider) {
            SharedInbox.write(.text(url.absoluteString), now: Date().timeIntervalSince1970)
        }

        openHostApp()
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

    // MARK: Host-app launch

    /// Extensions can't touch `UIApplication.shared`; walk the responder chain to an object that
    /// responds to `openURL:` and invoke it. This is the standard Share-Extension → host-app launch.
    private func openHostApp() {
        guard let url = URL(string: "englishhelper://share") else { return }
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
        extensionContext?.open(url, completionHandler: nil)
    }
}
