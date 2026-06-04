//
//  SettingsTests.swift
//  EnglishHelperTests
//
//  Settings: live health check ok/failed mapping, and persisted theme preference.
//

import Testing
import Foundation
import SwiftUI
import Domain
import Adapters
import Presentation

@Suite @MainActor struct SettingsTests {

    @Test func healthOkOnMock() async {
        let vm = SettingsViewModel(
            connectionHealth: ConnectionHealthInteractor(llm: MockLLMClient()),
            appVersion: "1.0", modelName: "claude-sonnet-4-6"
        )
        await vm.check()
        #expect(vm.health == .ok)
    }

    @Test func healthFailedWhenNotConfigured() async {
        let vm = SettingsViewModel(
            connectionHealth: ConnectionHealthInteractor(
                llm: StubLLMClient(behavior: .failure(.notConfigured), latency: .milliseconds(1))
            ),
            appVersion: "1.0", modelName: "m"
        )
        await vm.check()
        guard case .failed = vm.health else {
            Issue.record("expected .failed health, got \(vm.health)")
            return
        }
    }

    @Test func themePreferencePersists() {
        let key = "themePreference"
        UserDefaults.standard.removeObject(forKey: key)

        let store = ThemeStore()
        #expect(store.preference == .system)
        #expect(store.colorScheme == nil)

        store.preference = .dark
        let reloaded = ThemeStore()
        #expect(reloaded.preference == .dark)
        #expect(reloaded.colorScheme == .dark)

        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test func nativeLanguageSupportsFourLanguages() {
        #expect(TargetLanguage.allCases.count == 4)
        #expect(TargetLanguage.french.promptName == "French")
        #expect(TargetLanguage.spanish.promptName == "Spanish")
        #expect(TargetLanguage.french.speechLocale == "fr-FR")
        #expect(TargetLanguage.spanish.speechLocale == "es-ES")
        #expect(Set(TargetLanguage.allCases.map(\.abbreviation)) == ["RU", "EN", "FR", "ES"])
    }

    @Test func studiedLanguageSupportsFourLanguagesDefaultEnglish() {
        let key = "studiedLanguage"
        UserDefaults.standard.removeObject(forKey: key)
        #expect(StudiedLanguage.current == .english)   // default is English
        #expect(StudiedLanguage.allCases.count == 4)
        #expect(StudiedLanguage.french.promptName == "French")
        #expect(StudiedLanguage.french.speechLocale == "fr-FR")
        #expect(Set(StudiedLanguage.allCases.map(\.abbreviation)) == ["RU", "EN", "FR", "ES"])

        let store = StudiedLanguageStore()
        store.language = .spanish
        #expect(StudiedLanguage.current == .spanish)   // persists
        UserDefaults.standard.removeObject(forKey: key)
    }
}
