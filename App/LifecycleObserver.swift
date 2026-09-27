import AppKit
import EventKit
import Foundation

@MainActor
final class LifecycleObserver {
    private var tokens: [NSObjectProtocol] = []

    init(repository: EventRepository, ticker: MinuteTicker) {
        let workspace = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default

        observe(workspace, NSWorkspace.didWakeNotification) {
            repository.refresh(reason: .wake)
            ticker.restart()
        }
        observe(center, .NSCalendarDayChanged) {
            repository.refresh(reason: .dayChanged)
        }
        observe(center, .NSSystemTimeZoneDidChange) {
            repository.refresh(reason: .timeChanged)
            ticker.restart()
        }
        observe(center, .NSSystemClockDidChange) {
            repository.refresh(reason: .timeChanged)
            ticker.restart()
        }
        observe(center, .EKEventStoreChanged) {
            repository.refresh(reason: .storeChanged)
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor @Sendable () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        tokens.append(token)
    }
}
