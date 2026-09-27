import Foundation

public enum Selection: Equatable, Sendable {
    case none
    case upcoming(Event)
    case ongoing(Event)
    case beyondThreshold(Event)

    public var event: Event? {
        switch self {
        case .none: return nil
        case .upcoming(let e), .ongoing(let e), .beyondThreshold(let e): return e
        }
    }
}

public enum NextEventSelector {
    public static let switchLeadMinutes = 10

    public static func isTitleCandidate(_ event: Event) -> Bool {
        !event.isAllDay
            && event.status != .canceled
            && event.myResponse != .declined
            && event.myResponse != .tentative
            && event.myResponse != .needsAction
            && event.meetingLink != nil
            && !event.isSolo
    }

    public static func select(from events: [Event], now: Date, thresholdMinutes: Int) -> Selection {
        let candidates = events
            .filter { isTitleCandidate($0) && $0.end > now }
            .sorted(by: precedes)
        guard let first = candidates.first else { return .none }

        if first.start <= now {
            let lead = TimeInterval(switchLeadMinutes * 60)
            if let soon = candidates.first(where: { $0.start > now && $0.start.timeIntervalSince(now) <= lead }) {
                return .upcoming(soon)
            }
            return .ongoing(first)
        }
        if first.start.timeIntervalSince(now) <= TimeInterval(thresholdMinutes * 60) {
            return .upcoming(first)
        }
        return .beyondThreshold(first)
    }

    private static func rank(_ response: ResponseStatus) -> Int {
        switch response {
        case .accepted: return 0
        case .none: return 1
        default: return 2
        }
    }

    private static func precedes(_ a: Event, _ b: Event) -> Bool {
        if a.start != b.start { return a.start < b.start }
        if rank(a.myResponse) != rank(b.myResponse) { return rank(a.myResponse) < rank(b.myResponse) }
        if a.end != b.end { return a.end < b.end }
        return a.title < b.title
    }
}
