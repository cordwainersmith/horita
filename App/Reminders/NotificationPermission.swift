import Foundation
import UserNotifications

enum NotificationPermission {
    enum Access {
        case allowed, notRequested, blocked
    }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=dev.liranbaba.Horita")!

    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Authorized with the alert style set to None still delivers to Notification Center only, so no banner shows.
    static func access() async -> Access {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notRequested
        case .denied: return .blocked
        default: return settings.alertStyle == .none ? .blocked : .allowed
        }
    }
}
