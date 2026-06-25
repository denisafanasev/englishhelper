//
//  LongTaskCoordinator.swift
//  EnglishHelper — App
//
//  App-side implementation of `LongTaskCoordinating`: a background-task assertion keeps a slow LLM
//  request running for the short window iOS grants after the app is backgrounded, and a local
//  notification is posted if it finishes while the app is in the background — so the user can leave the
//  app mid-recognition / mid-explanation and tap back in to see the result. (Best-effort: iOS only
//  grants ~30s of background time, so a very long photo job may not finish in the background; the result
//  still appears when the user returns, just without a notification.)
//

import UIKit
import UserNotifications
import Presentation

@MainActor
final class LongTaskCoordinator: LongTaskCoordinating {
    private var tasks: [Int: (bg: UIBackgroundTaskIdentifier, kind: LongTaskKind)] = [:]
    private var nextToken = 0

    func begin(_ kind: LongTaskKind) -> Int {
        let token = nextToken
        nextToken += 1
        let bg = UIApplication.shared.beginBackgroundTask(withName: "llm.\(kind.rawValue).\(token)") {
            [weak self] in self?.expire(token)   // iOS reclaimed our time — release the assertion cleanly
        }
        tasks[token] = (bg, kind)
        return token
    }

    func end(_ token: Int, success: Bool) {
        guard let entry = tasks.removeValue(forKey: token) else { return }
        // In the foreground the user already sees the result — just release the assertion. In the
        // background, schedule the notification FIRST and release only after, so the app isn't suspended
        // before the notification is actually added (the assertion is what keeps us alive meanwhile).
        guard success, UIApplication.shared.applicationState == .background else {
            release(entry.bg)
            return
        }
        Task {
            await postReady(entry.kind)
            release(entry.bg)
        }
    }

    private func expire(_ token: Int) {
        guard let entry = tasks.removeValue(forKey: token) else { return }
        release(entry.bg)
    }

    private func release(_ bg: UIBackgroundTaskIdentifier) {
        if bg != .invalid { UIApplication.shared.endBackgroundTask(bg) }
    }

    private func postReady(_ kind: LongTaskKind) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        let copy = kind.notification(language: SharedLanguage.current())
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "englishhelper.result.\(kind.rawValue)", content: content, trigger: nil)
        try? await center.add(request)
    }
}
