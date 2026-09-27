import Foundation
import HoritaCore

protocol CalendarSource: Sendable {
    var kind: SourceKind { get }
    /// Non-nil when the source cannot fetch at all (no permission, not configured).
    var unavailableHealth: SourceHealth? { get }
    func fetchCalendars() async throws -> [CalendarInfo]
    func fetchEvents(in interval: DateInterval, calendarIDs: Set<String>) async throws -> [Event]
}

enum SourceHealth: Equatable, Sendable {
    case notConfigured
    case needsPermission
    case denied
    case ok(lastSuccess: Date)
    case failing(lastSuccess: Date?, reason: SourceError)
}

enum SourceError: Error, Equatable, Sendable {
    case unauthorized
    case blockedDeployment
    case scriptOutdated(Int)
    case network(String)
    case decoding(String)
}
