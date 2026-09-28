import Foundation

public enum ReminderPlanner {
    /// How late a reminder may still fire, for example after the Mac wakes from sleep.
    public static let lateGrace: TimeInterval = 300

    /// Non-muted title candidates whose reminder is due and not handled yet.
    /// `handled` holds `Event.id`s. The id includes the start time, so a moved event reminds again.
    public static func due(events: [Event], now: Date, leadMinutes: Int,
                           muted: Set<String>, excluding handled: Set<String>) -> [Event] {
        let lead = TimeInterval(leadMinutes * 60)
        return events
            .filter { event in
                NextEventSelector.isTitleCandidate(event)
                    && !muted.contains(event.muteKey)
                    && !handled.contains(event.id)
                    && event.start.addingTimeInterval(-lead) <= now
                    && now < min(event.start.addingTimeInterval(lateGrace), event.end)
            }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.title < $1.title }
    }
}
