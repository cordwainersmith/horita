import Foundation
import UserNotifications

enum NotificationPermission {
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=dev.liranbaba.Horita")!

    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
