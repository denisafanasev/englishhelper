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
            transcriptionHealth: TranscriptionHealthInteractor(service: MockTranscriptionService()),
            cacheAdmin: TranslationCacheAdminInteractor(cache: nil),
            appVersion: "1.0", modelName: "claude-sonnet-4-6", fastModelName: "claude-haiku-4-5",
            sonioxModelName: "stt-rt-v5"
        )
        await vm.check()
        #expect(vm.health == .ok)
        #expect(vm.sonioxHealth == .ok)   // the Soniox probe runs alongside the Claude ones
    }

    /// Soniox failures surface independently: Claude can be green while Soniox reports its own error.
    @Test func sonioxFailureIsIndependentOfClaude() async {
        let vm = SettingsViewModel(
            connectionHealth: ConnectionHealthInteractor(llm: MockLLMClient()),
            transcriptionHealth: TranscriptionHealthInteractor(
                service: MockTranscriptionService(failure: .unauthorized)
            ),
            cacheAdmin: TranslationCacheAdminInteractor(cache: nil),
            appVersion: "1.0", modelName: "m", fastModelName: "h", sonioxModelName: "s"
        )
        await vm.check()
        #expect(vm.health == .ok)
        guard case .failed = vm.sonioxHealth else {
            Issue.record("expected .failed sonioxHealth, got \(vm.sonioxHealth)")
            return
        }
    }

    /// No Soniox key → a "no key" failure (matching how a missing Claude key is shown), not a crash.
    @Test func sonioxNoKeyMapsToFailed() async {
        let health = await TranscriptionHealthInteractor(
            service: MockTranscriptionService(failure: .notConfigured)
        )()
        #expect(health == .failed(.noKey))
    }

    @Test func cacheStatsLoadAndClear() async {
        let cache = MockTranslationCache()
        await cache.setValue(Data([1]), forKey: "a")
        await cache.setValue(Data([2]), forKey: "b")
        _ = await cache.value(forKey: "a")   // one hit
        let vm = SettingsViewModel(
            connectionHealth: ConnectionHealthInteractor(llm: MockLLMClient()),
            transcriptionHealth: TranscriptionHealthInteractor(service: MockTranscriptionService()),
            cacheAdmin: TranslationCacheAdminInteractor(cache: cache),
            appVersion: "1.0", modelName: "m", fastModelName: "h", sonioxModelName: "s"
        )
        await vm.loadCacheStats()
        #expect(vm.cacheStats.entryCount == 2)
        #expect(vm.cacheStats.hitCount == 1)

        await vm.clearCache()
        #expect(vm.cacheStats.entryCount == 0)   // emptied
        #expect(vm.cacheStats.hitCount == 0)     // hit counter reset
    }

    @Test func healthFailedWhenNotConfigured() async {
        let vm = SettingsViewModel(
            connectionHealth: ConnectionHealthInteractor(
                llm: StubLLMClient(behavior: .failure(.notConfigured), latency: .milliseconds(1))
            ),
            transcriptionHealth: TranscriptionHealthInteractor(service: MockTranscriptionService()),
            cacheAdmin: TranslationCacheAdminInteractor(cache: nil),
            appVersion: "1.0", modelName: "m", fastModelName: "h", sonioxModelName: "s"
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

    @Test func onboardingDefaultsIncompleteThenPersistsCompletion() {
        let key = "didCompleteOnboarding"
        UserDefaults.standard.removeObject(forKey: key)

        let store = OnboardingStore()
        #expect(store.isComplete == false)   // first launch → onboarding shown

        store.complete()
        #expect(store.isComplete)
        #expect(OnboardingStore().isComplete)   // persists across launches

        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test func nativeLanguageSupportsSixLanguages() {
        #expect(TargetLanguage.allCases.count == 6)
        #expect(TargetLanguage.french.promptName == "French")
        #expect(TargetLanguage.spanish.promptName == "Spanish")
        #expect(TargetLanguage.german.promptName == "German")
        #expect(TargetLanguage.italian.promptName == "Italian")
        #expect(TargetLanguage.french.speechLocale == "fr-FR")
        #expect(TargetLanguage.spanish.speechLocale == "es-ES")
        #expect(TargetLanguage.german.speechLocale == "de-DE")
        #expect(TargetLanguage.italian.speechLocale == "it-IT")
        #expect(Set(TargetLanguage.allCases.map(\.abbreviation)) == ["RU", "EN", "FR", "ES", "DE", "IT"])
    }

    @Test func studiedLanguageSupportsSixLanguagesDefaultEnglish() {
        let key = "studiedLanguage"
        UserDefaults.standard.removeObject(forKey: key)
        #expect(StudiedLanguage.current == .english)   // default is English
        #expect(StudiedLanguage.allCases.count == 6)
        #expect(StudiedLanguage.french.promptName == "French")
        #expect(StudiedLanguage.german.promptName == "German")
        #expect(StudiedLanguage.italian.promptName == "Italian")
        #expect(StudiedLanguage.german.speechLocale == "de-DE")
        #expect(StudiedLanguage.italian.speechLocale == "it-IT")
        #expect(Set(StudiedLanguage.allCases.map(\.abbreviation)) == ["RU", "EN", "FR", "ES", "DE", "IT"])

        let store = StudiedLanguageStore()
        store.language = .spanish
        #expect(StudiedLanguage.current == .spanish)   // persists
        UserDefaults.standard.removeObject(forKey: key)
    }
}
