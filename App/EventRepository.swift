import Foundation
import os
import HoritaCore

enum RefreshReason {
    case timer, storeChanged, wake, dayChanged, timeChanged, menuOpened, settingsChanged, manual
}

@MainActor
final class EventRepository {
    private struct SourceState {
        var task: Task<Void, Never>?
        var pending = false
        var lastAttempt: Date?
        var lastSuccess: Date?
        var events: [Event] = []
        var calendars: [CalendarInfo] = []
        var health: SourceHealth = .notConfigured
    }

    static let pollInterval: TimeInterval = 180
    static let menuOpenMinimumGap: TimeInterval = 60

    private let model: AppModel
    private let sources: [any CalendarSource]
    private let preferences: Preferences
    private var states: [SourceKind: SourceState] = [:]
    private var timer: Timer?
    private let log = Logger(subsystem: "dev.liranbaba.Horita", category: "sync")

    init(model: AppModel, sources: [any CalendarSource], preferences: Preferences) {
        self.model = model
        self.sources = sources
        self.preferences = preferences
        for source in sources {
            states[source.kind] = SourceState()
        }
        preferences.onCalendarSelectionChanged = { [weak self] in
            self?.refresh(reason: .settingsChanged)
        }
    }

    func start() {
        refresh(reason: .manual)
        let timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: .timer) }
        }
        timer.tolerance = 20
        self.timer = timer
    }

    func refresh(reason: RefreshReason) {
        let kinds: [SourceKind]
        switch reason {
        case .storeChanged:
            kinds = [.eventKit]
        case .menuOpened:
            kinds = sources.map(\.kind).filter { kind in
                guard let last = states[kind]?.lastAttempt else { return true }
                return Date().timeIntervalSince(last) > Self.menuOpenMinimumGap
            }
        default:
            kinds = sources.map(\.kind)
        }
        for kind in kinds {
            refreshSource(kind)
        }
    }

    private func refreshSource(_ kind: SourceKind) {
        guard let source = sources.first(where: { $0.kind == kind }), states[kind] != nil else { return }
        if states[kind]?.task != nil {
            states[kind]?.pending = true
            return
        }
        states[kind]?.lastAttempt = .now
        states[kind]?.task = Task { [weak self] in
            await self?.perform(source)
            guard let self else { return }
            self.states[kind]?.task = nil
            if self.states[kind]?.pending == true {
                self.states[kind]?.pending = false
                self.refreshSource(kind)
            }
        }
    }

    private func perform(_ source: any CalendarSource) async {
        let kind = source.kind
        if let blocker = source.unavailableHealth {
            states[kind]?.health = blocker
            states[kind]?.events = []
            states[kind]?.calendars = []
            publish()
            return
        }
        do {
            let calendars = try await source.fetchCalendars()
            reconcileSelection(kind: kind, calendars: calendars)
            let enabledIDs = Set(calendars.filter { preferences.enabledCalendarKeys.contains($0.key) }.map(\.id))
            let events = enabledIDs.isEmpty ? [] : try await source.fetchEvents(in: Self.fetchWindow(), calendarIDs: enabledIDs)
            let success = Date()
            states[kind]?.calendars = calendars
            states[kind]?.events = events
            states[kind]?.lastSuccess = success
            states[kind]?.health = .ok(lastSuccess: success)
            log.info("\(kind.rawValue, privacy: .public) refreshed: \(calendars.count) calendars, \(events.count) events")
        } catch {
            let reason = (error as? SourceError) ?? .network(error.localizedDescription)
            let lastSuccess = states[kind]?.lastSuccess
            states[kind]?.health = .failing(lastSuccess: lastSuccess, reason: reason)
            log.error("\(kind.rawValue, privacy: .public) refresh failed: \(String(describing: reason), privacy: .public)")
        }
        publish()
    }

    static func fetchWindow(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 2, to: start) ?? start.addingTimeInterval(2 * 86_400)
        return DateInterval(start: start, end: end)
    }

    private func reconcileSelection(kind: SourceKind, calendars: [CalendarInfo]) {
        var eventKitCalendars = states[.eventKit]?.calendars ?? []
        var appsScriptCalendars = states[.appsScript]?.calendars ?? []
        if kind == .eventKit { eventKitCalendars = calendars } else { appsScriptCalendars = calendars }
        preferences.twins = TwinMatcher.twins(
            eventKit: eventKitCalendars,
            appsScript: appsScriptCalendars,
            scriptAccountEmail: appsScriptCalendars.first?.accountName
        )

        if kind == .eventKit {
            let known = Set(preferences.lastEventKitCalendarIDs)
            let newDefaults = calendars
                .filter { $0.isSuggestedDefault && !known.contains($0.id) }
                .filter { preferences.twins[$0.key].map { !preferences.enabledCalendarKeys.contains($0) } ?? true }
                .map(\.key)
            if !newDefaults.isEmpty {
                preferences.enableSilently(keys: Set(newDefaults))
                log.info("enabled \(newDefaults.count) new suggested-default calendars")
            }
            preferences.lastEventKitCalendarIDs = known.union(calendars.map(\.id)).sorted()
        }
    }

    private func publish() {
        let enabled = preferences.enabledCalendarKeys
        let twins = preferences.twins
        let eventKitEvents = states[.eventKit]?.events ?? []
        let eventKitSignatures = Set(eventKitEvents.map { "\($0.calendarKey)|\($0.title)|\($0.start.timeIntervalSince1970)|\($0.end.timeIntervalSince1970)" })

        var seen = Set<String>()
        var dropped = 0
        let merged = states.values.flatMap(\.events).filter { event in
            guard enabled.contains(event.calendarKey), event.status != .canceled else { return false }
            if event.source == .appsScript, let twin = twins[event.calendarKey],
               eventKitSignatures.contains("\(twin)|\(event.title)|\(event.start.timeIntervalSince1970)|\(event.end.timeIntervalSince1970)") {
                dropped += 1
                return false
            }
            return seen.insert(event.id).inserted
        }.sorted { a, b in
            if a.start != b.start { return a.start < b.start }
            if a.end != b.end { return a.end < b.end }
            return a.title < b.title
        }
        if dropped > 0 {
            log.warning("dropped \(dropped) Apps Script events duplicated by enabled EventKit twins")
        }

        let calendars = states.values.flatMap(\.calendars).sorted { ($0.accountName ?? "", $0.title) < ($1.accountName ?? "", $1.title) }
        var health: [SourceKind: SourceHealth] = [:]
        for (kind, state) in states { health[kind] = state.health }
        model.apply(events: merged, calendars: calendars, health: health)
    }
}
