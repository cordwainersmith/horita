import Foundation

public struct AppsScriptCalendarsResponse: Decodable, Sendable {
    public let version: Int
    public let user: String
    public let calendars: [AppsScriptCalendarDTO]
}

public struct AppsScriptCalendarDTO: Decodable, Sendable {
    public let id: String
    public let summary: String
    public let color: String
    public let primary: Bool
    public let accessRole: String?
}

public struct AppsScriptEventsResponse: Decodable, Sendable {
    public let version: Int
    public let user: String
    public let events: [AppsScriptEventDTO]
}

public struct AppsScriptPersonDTO: Decodable, Sendable {
    public let email: String?
    public let name: String?
    public let response: String?
    public let isSelf: Bool
    public let isOrganizer: Bool
    public let isResource: Bool

    enum CodingKeys: String, CodingKey {
        case email, name, response, organizer, resource
        case isSelf = "self"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        response = try c.decodeIfPresent(String.self, forKey: .response)
        isSelf = try c.decodeIfPresent(Bool.self, forKey: .isSelf) ?? false
        isOrganizer = try c.decodeIfPresent(Bool.self, forKey: .organizer) ?? false
        isResource = try c.decodeIfPresent(Bool.self, forKey: .resource) ?? false
    }
}

public struct AppsScriptEventDTO: Decodable, Sendable {
    public let id: String
    public let calendarId: String
    public let summary: String?
    public let status: String?
    public let eventType: String?
    public let allDay: Bool
    public let start: String
    public let end: String
    public let myResponse: String?
    public let organizer: AppsScriptPersonDTO?
    public let attendees: [AppsScriptPersonDTO]?
    public let location: String?
    public let description: String?
    public let htmlLink: String?
    public let conferenceUrl: String?
}

public struct AppsScriptErrorResponse: Decodable, Sendable {
    public let error: String
    public let version: Int?
}

public enum AppsScriptMapper {
    public static func calendars(from response: AppsScriptCalendarsResponse) -> [CalendarInfo] {
        response.calendars.map { dto in
            CalendarInfo(id: dto.id, source: .appsScript, title: dto.summary, colorHex: dto.color,
                         accountName: response.user, isSuggestedDefault: dto.primary)
        }
    }

    public static func events(from response: AppsScriptEventsResponse, calendars: [CalendarInfo]) -> [Event] {
        let byID = Dictionary(calendars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return response.events.compactMap { dto in
            guard dto.eventType != "workingLocation",
                  let start = parseDate(dto.start, allDay: dto.allDay),
                  let end = parseDate(dto.end, allDay: dto.allDay)
            else { return nil }
            let calendar = byID[dto.calendarId]
            let attendees = (dto.attendees ?? []).map(attendee)
            return Event(
                id: "gas|\(dto.calendarId)|\(dto.id)",
                source: .appsScript,
                calendarID: dto.calendarId,
                calendarTitle: calendar?.title ?? dto.calendarId,
                calendarColorHex: calendar?.colorHex ?? "#4285F4",
                title: dto.summary ?? "",
                start: start,
                end: end,
                isAllDay: dto.allDay,
                status: eventStatus(dto.status),
                myResponse: responseStatus(dto.myResponse),
                attendees: attendees,
                organizer: dto.organizer.map(attendee),
                location: nilIfEmpty(dto.location),
                notes: nilIfEmpty(dto.description),
                url: nil,
                conferenceURL: nilIfEmpty(dto.conferenceUrl).flatMap(URL.init(string:)),
                openInCalendarURL: nilIfEmpty(dto.htmlLink).flatMap(URL.init(string:)),
                accountEmail: response.user
            )
        }
    }

    static func parseDate(_ text: String, allDay: Bool) -> Date? {
        if allDay {
            let parts = text.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let components = DateComponents(calendar: calendar, year: parts[0], month: parts[1], day: parts[2])
            guard components.isValidDate else { return nil }
            return calendar.date(from: components)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }

    private static func attendee(_ dto: AppsScriptPersonDTO) -> Attendee {
        Attendee(name: nilIfEmpty(dto.name), email: nilIfEmpty(dto.email), response: responseStatus(dto.response),
                 isSelf: dto.isSelf, isOrganizer: dto.isOrganizer, isResource: dto.isResource)
    }

    private static func responseStatus(_ raw: String?) -> ResponseStatus {
        switch raw {
        case "accepted": return .accepted
        case "declined": return .declined
        case "tentative": return .tentative
        case "needsAction": return .needsAction
        default: return .none
        }
    }

    private static func eventStatus(_ raw: String?) -> EventStatus {
        switch raw {
        case "cancelled", "canceled": return .canceled
        case "tentative": return .tentative
        default: return .confirmed
        }
    }

    private static func nilIfEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
