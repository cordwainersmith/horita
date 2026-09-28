import Foundation
import Observation
import HoritaCore

@MainActor @Observable
final class AppModel {
    struct StatusRender: Equatable {
        let text: String?
        let iconName: String
        let accessibilityLabel: String
        /// Elapsed fraction of the ongoing meeting, rounded to 0.01. nil when nothing is in progress or setup is needed.
        let progress: Double?
        let hasOverlap: Bool
    }

    let preferences: Preferences
    private(set) var events: [Event] = []
    private(set) var calendars: [CalendarInfo] = []
    private(set) var health: [SourceKind: SourceHealth] = [:]
    var now: Date = .now

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    var selection: Selection {
        NextEventSelector.select(from: events, now: now, thresholdMinutes: preferences.thresholdMinutes, muted: preferences.mutedSeriesKeys)
    }

    var joinTarget: Event? { selection.event }

    var overlappingTargets: [Event] {
        NextEventSelector.overlapping(selection, events: events, now: now, muted: preferences.mutedSeriesKeys)
    }

    func apply(events: [Event], calendars: [CalendarInfo], health: [SourceKind: SourceHealth]) {
        self.events = events
        self.calendars = calendars
        self.health = health
    }

    /// No usable source at all: permission missing or denied and nothing else configured.
    var needsSetup: Bool {
        !health.isEmpty && health.values.allSatisfy { state in
            switch state {
            case .notConfigured, .needsPermission, .denied: return true
            case .ok, .failing: return false
            }
        }
    }

    /// Every source is failing and none has last-good data.
    var allSourcesFailingWithoutData: Bool {
        !health.isEmpty && health.values.allSatisfy { state in
            if case .failing(lastSuccess: nil, reason: _) = state { return true }
            return false
        }
    }

    var statusRender: StatusRender {
        let selection = self.selection
        let text = TitleFormatter.statusText(for: selection, now: now, hideTitle: preferences.hideTitle, maxLength: preferences.titleMaxLength)
        let needsAttention = needsSetup || allSourcesFailingWithoutData
        let iconName = needsAttention ? "StatusIconAlert" : "StatusIcon"
        let hasOverlap = !overlappingTargets.isEmpty
        var progress: Double?
        if !needsAttention, case .ongoing(let event) = selection {
            let total = event.end.timeIntervalSince(event.start)
            let elapsed = total > 0 ? now.timeIntervalSince(event.start) / total : 1
            progress = (min(max(elapsed, 0), 1) * 100).rounded() / 100
        }
        var label: String
        switch selection {
        case .upcoming(let event):
            label = "\(event.title), \(TitleFormatter.countdown(until: event.start, now: now))"
        case .ongoing(let event):
            label = "\(event.title), \(TitleFormatter.remaining(until: event.end, now: now))"
        case .none, .beyondThreshold:
            label = String(localized: "horita, no upcoming meetings")
        }
        if hasOverlap {
            label += String(localized: ", overlaps another meeting")
        }
        return StatusRender(text: text, iconName: iconName, accessibilityLabel: label, progress: progress, hasOverlap: hasOverlap)
    }
}
