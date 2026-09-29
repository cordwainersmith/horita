import AppKit
import Observation
import os
import HoritaCore

@MainActor
final class ReminderController {
    private let model: AppModel
    private let preferences: Preferences
    private let join: (Event) -> Void
    private let banner: BannerPresenter
    private let overlay = ReminderOverlay()
    /// Event ids already reminded or joined. In memory only.
    private var handled: Set<String> = []
    /// Snoozed event id -> its start, when the overlay shows once more.
    private var snoozed: [String: Date] = [:]
    private let log = Logger(subsystem: "dev.liranbaba.Horita", category: "reminders")

    init(model: AppModel, preferences: Preferences, join: @escaping (Event) -> Void) {
        self.model = model
        self.preferences = preferences
        self.join = join
        self.banner = BannerPresenter(
            lookup: { [weak model] id in model?.events.first { $0.id == id } },
            join: join,
            soundEnabled: { [weak preferences] in preferences?.reminderSound ?? false }
        )
    }

    func start() {
        observe()
    }

    func markJoined(_ event: Event) {
        handled.insert(event.id)
        snoozed[event.id] = nil
    }

    /// Only banners depend on notification permission, so other styles leave the last value alone.
    func refreshNotificationAccess() {
        guard preferences.reminderStyle == .banner else { return }
        Task {
            let access = await NotificationPermission.access()
            if model.notificationAccess != access {
                model.notificationAccess = access
            }
        }
    }

    /// Asks once while macOS has never prompted, otherwise opens horita's page in Notification settings.
    func fixNotificationAccess() {
        Task {
            if await NotificationPermission.access() == .notRequested {
                _ = await NotificationPermission.request()
            } else {
                NSWorkspace.shared.open(NotificationPermission.settingsURL)
            }
            refreshNotificationAccess()
        }
    }

    // Same one-shot re-registration as StatusItemController.observe().
    private func observe() {
        withObservationTracking {
            evaluate()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func evaluate() {
        let now = model.now
        let events = model.events
        let style = preferences.reminderStyle
        let lead = preferences.reminderLeadMinutes
        let muted = preferences.mutedSeriesKeys

        let ids = Set(events.map(\.id))
        handled.formIntersection(ids)
        snoozed = snoozed.filter { ids.contains($0.key) }
        guard style != .off else { return }
        // Runs on every minute tick, which picks up a change made in System Settings.
        refreshNotificationAccess()

        var toShow = ReminderPlanner.due(events: events, now: now, leadMinutes: lead, muted: muted, excluding: handled)
        handled.formUnion(toShow.map(\.id))

        if style == .fullScreen {
            for (id, start) in snoozed where now >= start {
                snoozed[id] = nil
                if let event = events.first(where: { $0.id == id }), !muted.contains(event.muteKey) {
                    toShow.append(event)
                }
            }
        }
        guard !toShow.isEmpty else { return }
        log.info("reminding \(toShow.count) event(s) via \(style.rawValue, privacy: .public)")

        switch style {
        case .banner:
            if model.notificationAccess != .allowed {
                log.error("notifications not allowed, banner will not show")
            }
            toShow.forEach { banner.present($0, now: now) }
        case .fullScreen:
            if preferences.reminderSound {
                NSSound(named: "Glass")?.play()
            }
            overlay.show(toShow, actions: .init(
                join: { [weak self] event in self?.join(event) },
                snooze: { [weak self] events in self?.snooze(events) }
            ))
        case .off:
            break
        }
    }

    private func snooze(_ events: [Event]) {
        let now = Date()
        for event in events where event.start > now {
            snoozed[event.id] = event.start
        }
    }
}
