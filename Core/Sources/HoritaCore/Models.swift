import Foundation

public enum SourceKind: String, Codable, Sendable, CaseIterable {
    case eventKit
    case appsScript
}

public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let source: SourceKind
    public let title: String
    public let colorHex: String
    public let accountName: String?
    public let isSuggestedDefault: Bool

    public var key: String { "\(source.rawValue):\(id)" }

    public init(id: String, source: SourceKind, title: String, colorHex: String, accountName: String?, isSuggestedDefault: Bool) {
        self.id = id
        self.source = source
        self.title = title
        self.colorHex = colorHex
        self.accountName = accountName
        self.isSuggestedDefault = isSuggestedDefault
    }
}

public enum ResponseStatus: String, Codable, Sendable {
    case accepted, declined, tentative, needsAction, none
}

public enum EventStatus: String, Codable, Sendable {
    case confirmed, tentative, canceled
}

public struct Attendee: Hashable, Sendable {
    public let name: String?
    public let email: String?
    public let response: ResponseStatus
    public let isSelf: Bool
    public let isOrganizer: Bool
    public let isResource: Bool

    public init(name: String? = nil, email: String? = nil, response: ResponseStatus = .none,
                isSelf: Bool = false, isOrganizer: Bool = false, isResource: Bool = false) {
        self.name = name
        self.email = email
        self.response = response
        self.isSelf = isSelf
        self.isOrganizer = isOrganizer
        self.isResource = isResource
    }
}

public enum MeetingService: String, Sendable {
    case zoom, googleMeet, teams
}

public struct MeetingLink: Hashable, Sendable {
    public let service: MeetingService
    public let url: URL

    public init(service: MeetingService, url: URL) {
        self.service = service
        self.url = url
    }
}

public struct Event: Identifiable, Hashable, Sendable {
    public let id: String
    public let source: SourceKind
    public let calendarID: String
    public let calendarTitle: String
    public let calendarColorHex: String
    public let title: String
    public let start: Date
    /// For all-day events, `end` is the exclusive local midnight after the last day,
    /// regardless of source (EventKit reports 23:59:59, Google reports an exclusive date).
    public let end: Date
    public let isAllDay: Bool
    public let status: EventStatus
    public let myResponse: ResponseStatus
    public let attendees: [Attendee]
    public let organizer: Attendee?
    public let location: String?
    public let notes: String?
    public let url: URL?
    public let conferenceURL: URL?
    public let openInCalendarURL: URL?
    public let accountEmail: String?
    public let meetingLink: MeetingLink?

    public var calendarKey: String { "\(source.rawValue):\(calendarID)" }
    public var isSolo: Bool { attendees.allSatisfy { $0.isSelf || $0.isResource } }

    public init(id: String, source: SourceKind, calendarID: String, calendarTitle: String, calendarColorHex: String,
                title: String, start: Date, end: Date, isAllDay: Bool, status: EventStatus, myResponse: ResponseStatus,
                attendees: [Attendee], organizer: Attendee?, location: String?, notes: String?, url: URL?,
                conferenceURL: URL?, openInCalendarURL: URL?, accountEmail: String?) {
        self.id = id
        self.source = source
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.status = status
        self.myResponse = myResponse
        self.attendees = attendees
        self.organizer = organizer
        self.location = location
        self.notes = notes
        self.url = url
        self.conferenceURL = conferenceURL
        self.openInCalendarURL = openInCalendarURL
        self.accountEmail = accountEmail
        self.meetingLink = LinkDetector.detect(conferenceURL: conferenceURL, url: url, location: location, notes: notes)
    }
}
