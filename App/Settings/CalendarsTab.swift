import Combine
import EventKit
import SwiftUI
import HoritaCore

struct CalendarsTab: View {
    @Bindable var state: SettingsState
    let model: AppModel
    let preferences: Preferences
    let eventKit: EventKitSource
    let repository: EventRepository

    @State private var authorization: EKAuthorizationStatus
    @State private var isRequesting = false

    private let didBecomeActive = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    private static let calendarPrivacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!

    init(state: SettingsState, model: AppModel, preferences: Preferences, eventKit: EventKitSource, repository: EventRepository) {
        self.state = state
        self.model = model
        self.preferences = preferences
        self.eventKit = eventKit
        self.repository = repository
        _authorization = State(initialValue: eventKit.authorization)
    }

    var body: some View {
        Form {
            Section("macOS Calendar") {
                switch authorization {
                case .fullAccess:
                    eventKitCalendars
                case .notDetermined:
                    Text("horita reads your calendars to show your next meeting in the menu bar. Nothing leaves your Mac.")
                        .font(.callout)
                    Button("Grant Access\u{2026}", action: requestAccess)
                        .disabled(isRequesting)
                default:
                    Text("Calendar access is turned off. Allow horita under Privacy & Security > Calendars, with full access.")
                        .font(.callout)
                    Button("Open System Settings\u{2026}") {
                        NSWorkspace.shared.open(Self.calendarPrivacyURL)
                    }
                }
            }

            if let notice = state.twinNotice {
                Text(notice).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(didBecomeActive) { _ in authorization = eventKit.authorization }
    }

    @ViewBuilder
    private var eventKitCalendars: some View {
        let calendars = model.calendars.filter { $0.source == .eventKit }
        if calendars.isEmpty {
            Text("No calendars found.").foregroundStyle(.secondary)
        } else {
            Toggle("All calendars", isOn: allBinding(for: calendars))
            let groups = Dictionary(grouping: calendars) { $0.accountName ?? String(localized: "Other") }
                .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            ForEach(groups, id: \.key) { account, members in
                Text(account).font(.headline)
                ForEach(members.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }, id: \.key) { calendar in
                    Toggle(isOn: binding(for: calendar)) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(nsColor: NSColor(hex: calendar.colorHex) ?? .systemGray))
                                .frame(width: 8, height: 8)
                            Text(calendar.title)
                        }
                    }
                }
            }
        }
    }

    private func allBinding(for calendars: [CalendarInfo]) -> Binding<Bool> {
        let keys = Set(calendars.map(\.key))
        return Binding(
            get: { keys.isSubset(of: preferences.enabledCalendarKeys) },
            set: { preferences.setCalendars(keys: keys, enabled: $0) }
        )
    }

    private func binding(for calendar: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { preferences.enabledCalendarKeys.contains(calendar.key) },
            set: { enabled in
                if let twin = preferences.setCalendar(key: calendar.key, enabled: enabled) {
                    showTwinNotice(enabled: calendar, disabledTwinKey: twin)
                }
            }
        )
    }

    private func showTwinNotice(enabled calendar: CalendarInfo, disabledTwinKey: String) {
        let other: SourceKind = calendar.source == .eventKit ? .appsScript : .eventKit
        let notice = String(localized: "\u{201C}\(calendar.title)\u{201D} is now shown from \(sourceName(calendar.source)). It was turned off in \(sourceName(other)) to avoid duplicates.")
        state.twinNotice = notice
        Task {
            try? await Task.sleep(for: .seconds(5))
            if state.twinNotice == notice { state.twinNotice = nil }
        }
    }

    private func sourceName(_ source: SourceKind) -> String {
        switch source {
        case .eventKit: return String(localized: "macOS Calendar")
        case .appsScript: return String(localized: "Google (Apps Script)")
        }
    }

    private func requestAccess() {
        isRequesting = true
        Task {
            let granted = (try? await eventKit.requestAccess()) ?? false
            authorization = eventKit.authorization
            isRequesting = false
            if granted {
                repository.refresh(reason: .settingsChanged)
            }
        }
    }
}
