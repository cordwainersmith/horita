import Foundation
import Testing
@testable import HoritaCore

@Suite struct AppsScriptDTOTests {
    let calendarsJSON = """
    {
      "version": 1,
      "user": "jane@example.com",
      "calendars": [
        { "id": "jane@example.com", "summary": "Jane Doe", "color": "#4285F4", "primary": true, "accessRole": "owner" },
        { "id": "team@group.calendar.google.com", "summary": "Team", "color": "#0B8043", "primary": false, "accessRole": "reader" }
      ]
    }
    """

    let eventsJSON = """
    {
      "version": 1,
      "user": "jane@example.com",
      "events": [
        {
          "id": "abc123_20260924T080000Z",
          "calendarId": "jane@example.com",
          "summary": "Standup",
          "status": "confirmed",
          "eventType": "default",
          "allDay": false,
          "start": "2026-09-24T10:00:00+03:00",
          "end": "2026-09-24T10:15:00+03:00",
          "myResponse": "accepted",
          "organizer": { "email": "lead@example.com", "name": "Team Lead", "self": false },
          "attendees": [
            { "email": "jane@example.com", "name": "Jane Doe", "response": "accepted", "self": true, "organizer": false, "resource": false },
            { "email": "room@resource.calendar.google.com", "name": "Room", "response": "accepted", "self": false, "organizer": false, "resource": true }
          ],
          "location": "",
          "description": "<b>Agenda</b> ...",
          "htmlLink": "https://www.google.com/calendar/event?eid=abc",
          "conferenceUrl": "https://meet.google.com/abc-defg-hij"
        },
        {
          "id": "allday1",
          "calendarId": "team@group.calendar.google.com",
          "summary": "Offsite",
          "status": "tentative",
          "eventType": "default",
          "allDay": true,
          "start": "2026-09-24",
          "end": "2026-09-26",
          "attendees": [],
          "location": "Berlin",
          "description": "",
          "htmlLink": null,
          "conferenceUrl": null
        },
        {
          "id": "wl1",
          "calendarId": "jane@example.com",
          "summary": "Home",
          "status": "confirmed",
          "eventType": "workingLocation",
          "allDay": true,
          "start": "2026-09-24",
          "end": "2026-09-25"
        },
        {
          "id": "frac",
          "calendarId": "jane@example.com",
          "summary": "Fractional",
          "status": "cancelled",
          "eventType": "default",
          "allDay": false,
          "start": "2026-09-24T12:00:00.000Z",
          "end": "2026-09-24T12:30:00.000Z"
        }
      ]
    }
    """

    func decodeCalendars() throws -> AppsScriptCalendarsResponse {
        try JSONDecoder().decode(AppsScriptCalendarsResponse.self, from: Data(calendarsJSON.utf8))
    }

    @Test func mapsCalendars() throws {
        let infos = AppsScriptMapper.calendars(from: try decodeCalendars())
        #expect(infos.map(\.key) == ["appsScript:jane@example.com", "appsScript:team@group.calendar.google.com"])
        #expect(infos[0].isSuggestedDefault)
        #expect(!infos[1].isSuggestedDefault)
        #expect(infos[0].accountName == "jane@example.com")
        #expect(infos[1].title == "Team")
        #expect(infos[1].colorHex == "#0B8043")
    }

    @Test func mapsEvents() throws {
        let calendars = AppsScriptMapper.calendars(from: try decodeCalendars())
        let response = try JSONDecoder().decode(AppsScriptEventsResponse.self, from: Data(eventsJSON.utf8))
        let events = AppsScriptMapper.events(from: response, calendars: calendars)
        #expect(events.map(\.id) == ["gas|jane@example.com|abc123_20260924T080000Z", "gas|team@group.calendar.google.com|allday1", "gas|jane@example.com|frac"])

        let standup = events[0]
        #expect(standup.source == .appsScript)
        #expect(standup.calendarTitle == "Jane Doe")
        #expect(standup.calendarColorHex == "#4285F4")
        #expect(standup.start == Date(timeIntervalSince1970: 1_790_233_200))
        #expect(standup.end.timeIntervalSince(standup.start) == 900)
        #expect(standup.myResponse == .accepted)
        #expect(standup.status == .confirmed)
        #expect(standup.organizer?.email == "lead@example.com")
        #expect(standup.attendees.count == 2)
        #expect(standup.attendees[0].isSelf)
        #expect(standup.attendees[1].isResource)
        #expect(standup.location == nil)
        #expect(standup.notes == "<b>Agenda</b> ...")
        #expect(standup.conferenceURL?.absoluteString == "https://meet.google.com/abc-defg-hij")
        #expect(standup.meetingLink?.service == .googleMeet)
        #expect(standup.openInCalendarURL?.absoluteString == "https://www.google.com/calendar/event?eid=abc")
        #expect(standup.accountEmail == "jane@example.com")
        #expect(standup.url == nil)

        let offsite = events[1]
        #expect(offsite.isAllDay)
        #expect(offsite.status == .tentative)
        #expect(offsite.myResponse == .none)
        #expect(offsite.start == Fixtures.at(0, 0))
        #expect(offsite.end == Fixtures.at(0, 0, dayOffset: 2))
        #expect(offsite.calendarTitle == "Team")
        #expect(offsite.location == "Berlin")
        #expect(offsite.notes == nil)

        let fractional = events[2]
        #expect(fractional.status == .canceled)
        #expect(fractional.start == Date(timeIntervalSince1970: 1_790_251_200))
    }

    @Test func unknownCalendarFallsBackToID() throws {
        let response = try JSONDecoder().decode(AppsScriptEventsResponse.self, from: Data(eventsJSON.utf8))
        let events = AppsScriptMapper.events(from: response, calendars: [])
        #expect(events[0].calendarTitle == "jane@example.com")
        #expect(events[0].calendarColorHex == "#4285F4")
    }

    @Test func decodesErrorResponse() throws {
        let error = try JSONDecoder().decode(AppsScriptErrorResponse.self, from: Data(#"{"error":"unauthorized","version":1}"#.utf8))
        #expect(error.error == "unauthorized")
        #expect(error.version == 1)
    }

    @Test func rejectsMalformedDates() {
        #expect(AppsScriptMapper.parseDate("2026-13-99", allDay: true) == nil)
        #expect(AppsScriptMapper.parseDate("not a date", allDay: false) == nil)
        #expect(AppsScriptMapper.parseDate("2026-09-24T10:00:00Z", allDay: false) != nil)
    }
}
