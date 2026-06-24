//
//  SharedInboxTests.swift
//  EnglishHelper — Tests
//
//  The App-Group hand-off used by the Share Extension: round-trip + single-consume + last-write-wins.
//  Uses the directory-injectable core so it runs without the App Group entitlement.
//

import Testing
import Foundation

@Suite struct SharedInboxTests {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func textRoundTripsAndSingleConsumes() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(SharedInbox.write(.text("hello world"), now: 0, in: dir))
        #expect(SharedInbox.consume(in: dir) == .text("hello world"))
        #expect(SharedInbox.consume(in: dir) == nil)   // consumed exactly once
    }

    @Test func imageRoundTripsAndSingleConsumes() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let bytes = Data([0x01, 0x02, 0x03, 0xFF, 0x00])
        #expect(SharedInbox.write(.image(bytes), now: 0, in: dir))
        #expect(SharedInbox.consume(in: dir) == .image(bytes))
        #expect(SharedInbox.consume(in: dir) == nil)
    }

    @Test func lastWriteWins() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        SharedInbox.write(.image(Data([0xAA])), now: 0, in: dir)
        SharedInbox.write(.text("latest"), now: 1, in: dir)
        #expect(SharedInbox.consume(in: dir) == .text("latest"))   // image file is replaced, no stale bytes
    }

    @Test func emptyInboxConsumesNil() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(SharedInbox.consume(in: dir) == nil)
    }

    // MARK: Share notification copy (posted by the extension to foreground the app)

    @Test func notificationCopyIsLocalizedAndKindAware() {
        // Image vs text pick the See it / Get it wording; language selects the locale; default is English.
        #expect(ShareNotification.text(isImage: true,  language: "ru").body == "Фото готово — нажмите, чтобы перевести")
        #expect(ShareNotification.text(isImage: false, language: "ru").body == "Текст готов — нажмите, чтобы объяснить")
        #expect(ShareNotification.text(isImage: true,  language: "en").body == "Photo ready — tap to translate")
        #expect(ShareNotification.text(isImage: false, language: "de").body.contains("erklären"))
        // Unknown language falls back to English, not empty.
        #expect(ShareNotification.text(isImage: true, language: "zz").body == "Photo ready — tap to translate")
        #expect(ShareNotification.text(isImage: true, language: "ru").title == "EnglishHelper")
    }
}
