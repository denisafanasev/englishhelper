//
//  ShareSupport.swift
//  EnglishHelper — App
//
//  App-side glue for the Share Extension hand-off. Because iOS won't let the extension foreground the
//  app, the extension posts a tappable LOCAL NOTIFICATION instead (see `ShareNotification`). For that to
//  show, the APP must hold notification permission — requested here, where a permission prompt works
//  normally (an extension can't reliably request it). Also mirrors the interface language into the App
//  Group so the extension can localize that notification.
//

import Foundation
import UserNotifications

enum ShareSupport {
    /// Run once when the app becomes active: mirror the language and ensure notification permission.
    static func prepare() async {
        if let code = UserDefaults.standard.string(forKey: "interfaceLanguage") {
            SharedLanguage.mirror(code)   // only when the user picked an explicit interface language
        }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Cancel the PENDING (delayed) share notification and clear any delivered one, once the payload has
    /// been consumed — so when automatic foregrounding worked, the fallback banner never fires.
    static func clearShareNotification() {
        let center = UNUserNotificationCenter.current()
        let ids = [ShareNotification.requestIdentifier]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
