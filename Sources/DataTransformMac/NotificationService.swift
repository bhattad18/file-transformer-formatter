import Foundation
import UserNotifications

enum NotificationService {
    private static let lastNotifiedVersionKey = "last_notified_update_version"

    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyUpdateAvailableIfNeeded(version: String) {
        let lastNotified = UserDefaults.standard.string(forKey: lastNotifiedVersionKey)
        guard lastNotified != version else { return }

        let content = UNMutableNotificationContent()
        content.title = "Update Available"
        content.body = "Version \(version) of \(AppInfo.appName) is available."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "update-\(version)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(version, forKey: lastNotifiedVersionKey)
    }
}
