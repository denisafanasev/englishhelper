//
//  BackgroundAudioTests.swift
//  EnglishHelperTests
//
//  The Online interpreter must KEEP translating when the app is backgrounded or the screen locks.
//  That behavior hangs on the app declaring the "audio" background mode (plus the adapter's active
//  `.record` session) — one plist line that nothing else would catch if it silently disappeared.
//  Located on disk via #filePath, same as ForbiddenImportTests.
//

import Testing
import Foundation

@Suite struct BackgroundAudioTests {

    @Test func appDeclaresAudioBackgroundMode() throws {
        let plistURL = URL(filePath: #filePath)
            .deletingLastPathComponent()    // …/Tests
            .deletingLastPathComponent()    // repo root
            .appending(path: "App/Info.plist")
        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: plistURL), format: nil
        ) as? [String: Any]
        let modes = plist?["UIBackgroundModes"] as? [String]
        #expect(modes?.contains("audio") == true,
                "App/Info.plist must declare UIBackgroundModes=audio — without it a live session dies the moment the screen locks")
    }
}
