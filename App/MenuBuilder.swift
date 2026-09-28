import AppKit
import KeyboardShortcuts
import HoritaCore

struct MenuActions {
    let join: (Event) -> Void
    let copyLink: (URL) -> Void
    let openURL: (URL) -> Void
    let setMuted: (Event, Bool) -> Void
    let openSettings: (SettingsTab) -> Void
    let checkForUpdates: (() -> Void)?
    let quit: () -> Void
}

@MainActor
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fireAction), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func fireAction() {
        handler()
    }
}

@MainActor
enum MenuBuilder {
    private static let rowTitleMaxLength = 50
    private static let allDayLineMaxLength = 60
    private static let attendeeRowLimit = 10
    private static let notesMaxCharacters = 300
    private static let calendarPrivacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!

    static func build(model: AppModel, actions: MenuActions) -> NSMenu {
        let menu = NSMenu()
        let now = model.now
        let section = DayLayout.today(events: model.events, now: now, calendar: .current)

        if let target = model.joinTarget {
            let item = joinItem(for: target, now: now, actions: actions)
            item.setShortcut(for: .joinNext)
            menu.addItem(item)
            for other in model.overlappingTargets {
                menu.addItem(joinItem(for: other, now: now, actions: actions))
            }
            menu.addItem(.separator())
        }

        let healthItems = healthRows(model: model, actions: actions)
        if !healthItems.isEmpty {
            healthItems.forEach(menu.addItem)
            menu.addItem(.separator())
        }

        menu.addItem(.sectionHeader(title: String(localized: "Today \u{00B7} \(headerDate(section.day))")))

        if let summary = section.summary {
            menu.addItem(summaryItem(summary))
        }

        if !section.allDayTitles.isEmpty {
            let line = String(localized: "All day: \(section.allDayTitles.joined(separator: ", "))")
            menu.addItem(disabledItem(TitleFormatter.truncate(line, maxLength: allDayLineMaxLength)))
        }

        let timeFormatter = DateFormatter()
        timeFormatter.setLocalizedDateFormatFromTemplate("jmm")
        let muted = model.preferences.mutedSeriesKeys
        let tomorrowRow = DayLayout.tomorrowFirst(events: model.events, now: now, calendar: .current).map { event in
            DayRow(event: event, style: event.myResponse == .tentative || event.myResponse == .needsAction ? .tentative : .normal)
        }
        let tabLocation = timeColumnWidth(rows: section.rows + [tomorrowRow].compactMap { $0 }, formatter: timeFormatter)

        if section.rows.isEmpty {
            if section.allDayTitles.isEmpty {
                menu.addItem(disabledItem(String(localized: "Nothing on the calendar today")))
            }
        } else {
            for row in section.rows {
                menu.addItem(rowItem(row, now: now, muted: muted, timeFormatter: timeFormatter, tabLocation: tabLocation, actions: actions))
            }
            if section.allPast {
                menu.addItem(disabledItem(String(localized: "No more meetings today")))
            }
        }

        if let tomorrowRow {
            menu.addItem(.sectionHeader(title: String(localized: "Tomorrow")))
            menu.addItem(rowItem(tomorrowRow, now: now, muted: muted, timeFormatter: timeFormatter, tabLocation: tabLocation, actions: actions))
        }

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: String(localized: "Settings\u{2026}"), keyEquivalent: ",") { actions.openSettings(.general) })
        if let checkForUpdates = actions.checkForUpdates {
            menu.addItem(ActionMenuItem(title: String(localized: "Check for Updates\u{2026}"), handler: checkForUpdates))
        } else {
            menu.addItem(disabledItem(String(localized: "Check for Updates\u{2026}")))
        }
        menu.addItem(ActionMenuItem(title: String(localized: "Quit horita"), keyEquivalent: "q", handler: actions.quit))
        return menu
    }

    private static func joinItem(for event: Event, now: Date, actions: MenuActions) -> ActionMenuItem {
        let clock = event.start > now
            ? TitleFormatter.countdown(until: event.start, now: now)
            : TitleFormatter.remaining(until: event.end, now: now)
        let title = String(localized: "Join: \(TitleFormatter.truncate(event.title, maxLength: rowTitleMaxLength)) \u{00B7} \(clock)")
        return ActionMenuItem(title: title) { actions.join(event) }
    }

    private static func summaryItem(_ summary: DaySummary) -> NSMenuItem {
        var parts = [
            summary.meetingCount == 1 ? String(localized: "1 meeting") : String(localized: "\(summary.meetingCount) meetings"),
            TitleFormatter.duration(seconds: summary.busy),
        ]
        if let freeAfter = summary.freeAfter {
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("jmm")
            parts.append(String(localized: "free after \(formatter.string(from: freeAfter))"))
        }
        let item = disabledItem("")
        item.attributedTitle = NSAttributedString(string: parts.joined(separator: " \u{00B7} "),
                                                  attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.secondaryLabelColor])
        return item
    }

    // MARK: - Health rows

    private static func healthRows(model: AppModel, actions: MenuActions) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        if model.health[.eventKit] == .denied {
            let item = ActionMenuItem(title: String(localized: "Calendar access denied. Open System Settings\u{2026}")) {
                actions.openURL(calendarPrivacyURL)
            }
            item.image = warningImage()
            items.append(item)
        }
        let anySourceReady = model.health.values.contains { if case .ok = $0 { return true } else { return false } }
        let anyEnabled = model.calendars.contains { model.preferences.enabledCalendarKeys.contains($0.key) }
        if anySourceReady, !model.calendars.isEmpty, !anyEnabled {
            let item = ActionMenuItem(title: String(localized: "No calendars selected. Choose calendars\u{2026}")) {
                actions.openSettings(.calendars)
            }
            item.image = warningImage()
            items.append(item)
        }
        return items
    }

    // MARK: - Rows

    private static func rowItem(_ row: DayRow, now: Date, muted: Set<String>, timeFormatter: DateFormatter, tabLocation: CGFloat, actions: MenuActions) -> NSMenuItem {
        let event = row.event
        let isMuted = muted.contains(event.muteKey)
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.image = colorDot(hex: event.calendarColorHex)
        item.attributedTitle = rowTitle(row, now: now, isMuted: isMuted, timeFormatter: timeFormatter, tabLocation: tabLocation)
        item.submenu = detailsMenu(for: event, isMuted: isMuted, timeFormatter: timeFormatter, actions: actions)
        return item
    }

    private static func rowTitle(_ row: DayRow, now: Date, isMuted: Bool, timeFormatter: DateFormatter, tabLocation: CGFloat) -> NSAttributedString {
        let event = row.event
        let baseFont = NSFont.menuFont(ofSize: 0)
        var font = baseFont
        var color = NSColor.labelColor
        var strikethrough = false
        var suffix = ""

        switch row.style {
        case .declined:
            strikethrough = true
            color = .secondaryLabelColor
        case .past:
            color = .secondaryLabelColor
        case .ongoing:
            font = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
            suffix = " \u{00B7} \(TitleFormatter.remaining(until: event.end, now: now))"
        case .tentative:
            font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        case .normal:
            break
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: tabLocation, options: [:])]
        paragraph.defaultTabInterval = tabLocation
        paragraph.lineBreakMode = .byTruncatingTail

        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        if strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        let time = timeFormatter.string(from: event.start)
        let title = TitleFormatter.truncate(event.title, maxLength: rowTitleMaxLength)
        let result = NSMutableAttributedString(string: "\(time)\t\(title)\(suffix)", attributes: attributes)
        result.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: baseFont.pointSize, weight: .regular), range: NSRange(location: 0, length: (time as NSString).length))

        if event.meetingLink != nil {
            result.append(NSAttributedString(string: " ", attributes: attributes))
            result.append(symbolAttachment("video", description: String(localized: "Has meeting link"), font: font, color: color))
        }
        if row.overlapsAnother {
            result.append(NSAttributedString(string: " ", attributes: attributes))
            result.append(symbolAttachment("square.on.square", description: String(localized: "Overlaps another meeting"), font: font, color: color))
        } else if row.backToBack {
            result.append(NSAttributedString(string: " ", attributes: attributes))
            result.append(symbolAttachment("arrow.right.to.line", description: String(localized: "Back-to-back"), font: font, color: color))
        }
        if isMuted {
            result.append(NSAttributedString(string: " ", attributes: attributes))
            result.append(symbolAttachment("eye.slash", description: String(localized: "Not shown in menu bar"), font: font, color: color))
        }
        return result
    }

    private static func timeColumnWidth(rows: [DayRow], formatter: DateFormatter) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .regular)
        let widest = rows.map { (formatter.string(from: $0.event.start) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 40
        return ceil(widest) + 12
    }

    // MARK: - Details submenu

    private static func detailsMenu(for event: Event, isMuted: Bool, timeFormatter: DateFormatter, actions: MenuActions) -> NSMenu {
        let menu = NSMenu()

        if let link = event.meetingLink {
            let join = ActionMenuItem(title: String(localized: "Join \(serviceName(link.service))")) { actions.join(event) }
            join.attributedTitle = NSAttributedString(string: join.title, attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize)])
            menu.addItem(join)
            menu.addItem(ActionMenuItem(title: String(localized: "Copy Meeting Link")) { actions.copyLink(link.url) })
        }
        if isMuted || NextEventSelector.isTitleCandidate(event) {
            let mute = ActionMenuItem(title: String(localized: "Don't Show in Menu Bar")) { actions.setMuted(event, !isMuted) }
            mute.state = isMuted ? .on : .off
            menu.addItem(mute)
        }
        if menu.numberOfItems > 0 {
            menu.addItem(.separator())
        }

        let range = "\(timeFormatter.string(from: event.start))-\(timeFormatter.string(from: event.end))"
        menu.addItem(disabledItem("\(range) (\(TitleFormatter.duration(from: event.start, to: event.end)))"))

        let calendarItem = disabledItem(event.calendarTitle)
        calendarItem.image = colorDot(hex: event.calendarColorHex)
        menu.addItem(calendarItem)

        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty,
           location != event.meetingLink?.url.absoluteString {
            menu.addItem(disabledItem(String(localized: "Location: \(location)")))
        }

        if let organizer = event.organizer, let name = displayName(organizer) {
            menu.addItem(disabledItem(String(localized: "Organizer: \(name)")))
        }

        let people = event.attendees.filter { !$0.isResource }
        if !people.isEmpty {
            menu.addItem(disabledItem(String(localized: "Attendees (\(people.count))")))
            for attendee in people.prefix(attendeeRowLimit) {
                menu.addItem(disabledItem("\(responseSymbol(attendee.response)) \(displayName(attendee) ?? "?")"))
            }
            if people.count > attendeeRowLimit {
                menu.addItem(disabledItem(String(localized: "and \(people.count - attendeeRowLimit) more")))
            }
        }

        if let notes = event.notes {
            let plain = String(HTMLText.plainText(notes).prefix(notesMaxCharacters))
            if !plain.isEmpty {
                let item = disabledItem("")
                item.attributedTitle = NSAttributedString(string: HTMLText.wrap(plain, columns: 60, maxLines: 6),
                                                          attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.secondaryLabelColor])
                menu.addItem(item)
            }
        }

        if let url = event.openInCalendarURL {
            menu.addItem(.separator())
            let title = event.source == .appsScript ? String(localized: "Open in Google Calendar") : String(localized: "Open in Calendar")
            menu.addItem(ActionMenuItem(title: title) { actions.openURL(url) })
        }
        return menu
    }

    // MARK: - Helpers

    private static func disabledItem(_ title: String) -> NSMenuItem {
        NSMenuItem(title: title, action: nil, keyEquivalent: "")
    }

    private static func headerDate(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEEdMMM", options: 0, locale: .current)
        return formatter.string(from: day)
    }

    private static func serviceName(_ service: MeetingService) -> String {
        switch service {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .teams: return "Teams"
        }
    }

    private static func responseSymbol(_ response: ResponseStatus) -> String {
        switch response {
        case .accepted: return "\u{2713}"
        case .declined: return "\u{2717}"
        case .tentative: return "?"
        case .needsAction, .none: return "\u{00B7}"
        }
    }

    private static func displayName(_ attendee: Attendee) -> String? {
        if let name = attendee.name, !name.isEmpty { return name }
        if let email = attendee.email, !email.isEmpty { return email }
        return nil
    }

    private static func symbolAttachment(_ name: String, description: String, font: NSFont, color: NSColor) -> NSAttributedString {
        let attachment = NSTextAttachment()
        let configuration = NSImage.SymbolConfiguration(pointSize: font.pointSize * 0.85, weight: .regular)
            .applying(.init(paletteColors: [color]))
        attachment.image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        if let size = attachment.image?.size {
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - size.height) / 2, width: size.width, height: size.height)
        }
        return NSAttributedString(attachment: attachment)
    }

    private static func warningImage() -> NSImage? {
        NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: String(localized: "Warning"))
    }

    static func colorDot(hex: String, diameter: CGFloat = 8) -> NSImage {
        let color = NSColor(hex: hex) ?? .systemGray
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: 1)
    }
}
