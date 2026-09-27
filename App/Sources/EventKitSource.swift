import CoreGraphics
import EventKit
import Foundation
import HoritaCore

// EKEventStore is documented thread-safe; all EKEvent/EKCalendar objects stay inside the detached tasks.
final class EventKitSource: CalendarSource, @unchecked Sendable {
    let kind: SourceKind = .eventKit
    let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    var authorization: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var unavailableHealth: SourceHealth? {
        switch authorization {
        case .fullAccess: return nil
        case .notDetermined: return .needsPermission
        default: return .denied
        }
    }

    func requestAccess() async throws -> Bool {
        let granted = try await store.requestFullAccessToEvents()
        if granted { store.reset() }
        return granted
    }

    func fetchCalendars() async throws -> [CalendarInfo] {
        await Task.detached(priority: .userInitiated) { [self] in
            store.calendars(for: .event).map(Self.calendarInfo)
        }.value
    }

    func fetchEvents(in interval: DateInterval, calendarIDs: Set<String>) async throws -> [Event] {
        await Task.detached(priority: .userInitiated) { [self] in
            let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
            guard !calendars.isEmpty else { return [] }
            let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
            return store.events(matching: predicate).map(Self.event)
        }.value
    }

    static func calendarInfo(_ calendar: EKCalendar) -> CalendarInfo {
        let isSystemGenerated = calendar.type == .birthday || calendar.type == .subscription
        let isHoliday = calendar.title.range(of: "holiday", options: .caseInsensitive) != nil
        return CalendarInfo(
            id: calendar.calendarIdentifier,
            source: .eventKit,
            title: calendar.title,
            colorHex: hexString(calendar.cgColor),
            accountName: calendar.source?.title,
            isSuggestedDefault: !isSystemGenerated && !isHoliday
        )
    }

    static func event(_ ekEvent: EKEvent) -> Event {
        let calendar = Calendar.current
        let originalStart = ekEvent.startDate ?? Date()
        var end = ekEvent.endDate ?? originalStart
        var isAllDay = ekEvent.isAllDay

        let spansWholeDays = (calendar.dateComponents([.day], from: originalStart, to: end).day ?? 0) >= 1
        if !isAllDay, spansWholeDays,
           originalStart == calendar.startOfDay(for: originalStart),
           end == calendar.startOfDay(for: end) {
            isAllDay = true
        }
        if isAllDay, end != calendar.startOfDay(for: end) {
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        }

        let organizerURL = ekEvent.organizer?.url
        let attendees = (ekEvent.attendees ?? []).map { attendee($0, organizerURL: organizerURL) }
        let accountTitle = ekEvent.calendar?.source?.title

        return Event(
            id: "\(ekEvent.calendarItemIdentifier)|\(Int(originalStart.timeIntervalSince1970))",
            source: .eventKit,
            calendarID: ekEvent.calendar?.calendarIdentifier ?? "",
            calendarTitle: ekEvent.calendar?.title ?? "",
            calendarColorHex: hexString(ekEvent.calendar?.cgColor),
            title: ekEvent.title ?? "",
            start: originalStart,
            end: end,
            isAllDay: isAllDay,
            status: eventStatus(ekEvent.status),
            myResponse: myResponse(for: ekEvent),
            attendees: attendees,
            organizer: ekEvent.organizer.map { attendee($0, organizerURL: organizerURL) },
            location: ekEvent.location,
            notes: ekEvent.notes,
            url: ekEvent.url,
            conferenceURL: nil,
            openInCalendarURL: URL(string: "ical://ekevent/\(ekEvent.calendarItemIdentifier)"),
            accountEmail: accountTitle.flatMap { $0.contains("@") ? $0 : nil }
        )
    }

    private static func myResponse(for ekEvent: EKEvent) -> ResponseStatus {
        guard let attendees = ekEvent.attendees, !attendees.isEmpty else { return .none }
        if let me = attendees.first(where: \.isCurrentUser) {
            return responseStatus(me.participantStatus)
        }
        if ekEvent.organizer?.isCurrentUser == true { return .accepted }
        return .none
    }

    private static func attendee(_ participant: EKParticipant, organizerURL: URL?) -> Attendee {
        let url = participant.url
        let email = url.scheme?.lowercased() == "mailto" ? String(url.absoluteString.dropFirst("mailto:".count)) : nil
        return Attendee(
            name: participant.name,
            email: email,
            response: responseStatus(participant.participantStatus),
            isSelf: participant.isCurrentUser,
            isOrganizer: organizerURL != nil && participant.url == organizerURL,
            isResource: participant.participantType == .room || participant.participantType == .resource
        )
    }

    private static func responseStatus(_ status: EKParticipantStatus) -> ResponseStatus {
        switch status {
        case .accepted: return .accepted
        case .declined: return .declined
        case .tentative: return .tentative
        case .pending: return .needsAction
        default: return .none
        }
    }

    private static func eventStatus(_ status: EKEventStatus) -> EventStatus {
        switch status {
        case .canceled: return .canceled
        case .tentative: return .tentative
        default: return .confirmed
        }
    }

    static func hexString(_ color: CGColor?) -> String {
        guard let color,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: space, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3
        else { return "#8E8E93" }
        let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(components[0]), channel(components[1]), channel(components[2]))
    }
}
