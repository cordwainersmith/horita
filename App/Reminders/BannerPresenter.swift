import Foundation
import os
import UserNotifications
import HoritaCore

@MainActor
final class BannerPresenter: NSObject, UNUserNotificationCenterDelegate {
    private nonisolated static let categoryID = "meeting"
    private nonisolated static let joinActionID = "join"
    private nonisolated static let eventIDKey = "eventID"

    private let center = UNUserNotificationCenter.current()
    private let lookup: (String) -> Event?
    private let join: (Event) -> Void
    private let soundEnabled: () -> Bool
    private let log = Logger(subsystem: "dev.liranbaba.Horita", category: "reminders")

    init(lookup: @escaping (String) -> Event?, join: @escaping (Event) -> Void, soundEnabled: @escaping () -> Bool) {
        self.lookup = lookup
        self.join = join
        self.soundEnabled = soundEnabled
        super.init()
        let joinAction = UNNotificationAction(identifier: Self.joinActionID, title: String(localized: "Join"), options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.categoryID, actions: [joinAction], intentIdentifiers: [])])
        center.delegate = self
    }

    func present(_ event: Event, now: Date) {
        let content = UNMutableNotificationContent()
        content.title = TitleFormatter.truncate(event.title, maxLength: 60)
        content.body = "\(TitleFormatter.countdown(until: event.start, now: now)) \u{00B7} \(event.calendarTitle)"
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [Self.eventIDKey: event.id]
        if soundEnabled() {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
        center.add(request) { [log] error in
            if let error {
                log.error("banner failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        guard action == Self.joinActionID || action == UNNotificationDefaultActionIdentifier,
              let id = response.notification.request.content.userInfo[Self.eventIDKey] as? String
        else { return }
        await MainActor.run {
            if let event = lookup(id) {
                join(event)
            } else {
                log.info("banner event no longer in the calendar")
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run { soundEnabled() ? [.banner, .sound] : [.banner] }
    }
}
