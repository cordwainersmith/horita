import Foundation
@testable import HoritaCore

enum Fixtures {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    static let baseDay: Date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24))!

    static func at(_ hour: Int, _ minute: Int, dayOffset: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: baseDay)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    static let me = Attendee(name: "Me", email: "me@example.com", response: .accepted, isSelf: true)
    static let pat = Attendee(name: "Pat", email: "pat@example.com", response: .accepted)
    static let room = Attendee(name: "Room 4", email: "room4@resource.calendar.google.com", response: .accepted, isResource: true)
    static let zoom = "https://zoom.us/j/123456789"
}

func makeEvent(
    id: String = UUID().uuidString,
    title: String = "Standup",
    start: Date,
    end: Date,
    isAllDay: Bool = false,
    status: EventStatus = .confirmed,
    myResponse: ResponseStatus = .accepted,
    attendees: [Attendee] = [Fixtures.me, Fixtures.pat],
    location: String? = Fixtures.zoom,
    notes: String? = nil,
    url: URL? = nil,
    conferenceURL: URL? = nil,
    source: SourceKind = .eventKit,
    calendarID: String = "cal-1",
    calendarTitle: String = "Work",
    accountEmail: String? = nil,
    seriesID: String? = nil
) -> Event {
    Event(id: id, source: source, calendarID: calendarID, calendarTitle: calendarTitle, calendarColorHex: "#FF0000",
          title: title, start: start, end: end, isAllDay: isAllDay, status: status, myResponse: myResponse,
          attendees: attendees, organizer: nil, location: location, notes: notes, url: url,
          conferenceURL: conferenceURL, openInCalendarURL: nil, accountEmail: accountEmail, seriesID: seriesID)
}
