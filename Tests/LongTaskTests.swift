//
//  LongTaskTests.swift
//  EnglishHelper — Tests
//
//  Background-completion plumbing: localized notification copy + the withBackgroundCompletion wrapper
//  contract (begin -> end(success) around the op; cancellation/errors end WITHOUT notifying).
//

import Testing
import Foundation
import Presentation

@Suite @MainActor struct LongTaskTests {

    @Test func notificationCopyIsLocalizedAndKindAware() {
        #expect(LongTaskKind.translation.notification(language: "ru").body == "Перевод готов — откройте, чтобы посмотреть")
        #expect(LongTaskKind.explanation.notification(language: "ru").body == "Объяснение готово — откройте, чтобы посмотреть")
        #expect(LongTaskKind.photoTranslate.notification(language: "en").body == "Translation ready — open to view")
        #expect(LongTaskKind.photoExplain.notification(language: "zz").body == "Explanation ready — open to view")  // fallback
        #expect(LongTaskKind.translation.notification(language: "ru").title == "EnglishHelper")
    }

    @Test func wrapperBeginsThenEndsSuccessfullyOnSuccess() async throws {
        let spy = SpyCoordinator()
        let value = try await withBackgroundCompletion(spy, .photoTranslate) { 42 }
        #expect(value == 42)
        #expect(spy.begun == [.photoTranslate])
        #expect(spy.ended.count == 1)
        #expect(spy.ended.first?.success == true)
    }

    @Test func wrapperEndsWithoutSuccessOnThrow() async {
        let spy = SpyCoordinator()
        await #expect(throws: CancellationError.self) {
            try await withBackgroundCompletion(spy, .explanation) { throw CancellationError() }
        }
        #expect(spy.begun == [.explanation])
        #expect(spy.ended.first?.success == false)   // a superseded/failed op never notifies
    }

    @Test func nilCoordinatorIsTransparentPassThrough() async throws {
        let value = try await withBackgroundCompletion(nil, .translation) { "ok" }
        #expect(value == "ok")
    }
}

@MainActor
private final class SpyCoordinator: LongTaskCoordinating {
    private(set) var begun: [LongTaskKind] = []
    private(set) var ended: [(token: Int, success: Bool)] = []
    private var next = 0
    func begin(_ kind: LongTaskKind) -> Int { begun.append(kind); defer { next += 1 }; return next }
    func end(_ token: Int, success: Bool) { ended.append((token, success)) }
}
