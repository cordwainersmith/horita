import AppKit
import os
import HoritaCore

@MainActor
enum Joiner {
    private static let log = Logger(subsystem: "dev.liranbaba.Horita", category: "join")

    static func join(_ event: Event?) {
        guard let event else {
            NSSound.beep()
            return
        }
        guard let link = event.meetingLink else {
            if let url = event.url, ["http", "https"].contains(url.scheme?.lowercased()) {
                log.info("opening plain event URL")
                open(url, fallback: nil)
            } else {
                NSSound.beep()
            }
            return
        }
        let plan = JoinPlanner.plan(for: link, accountEmail: event.accountEmail)
        log.info("joining \(link.service.rawValue, privacy: .public) via \(plan.primary.scheme ?? "?", privacy: .public)")
        open(plan.primary, fallback: plan.fallback)
    }

    private static func open(_ url: URL, fallback: URL?) {
        if let fallback, NSWorkspace.shared.urlForApplication(toOpen: url) == nil {
            log.info("no handler for \(url.scheme ?? "?", privacy: .public), using fallback")
            NSWorkspace.shared.open(fallback)
            return
        }
        NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard error != nil, let fallback else { return }
            Task { @MainActor in
                log.info("primary open failed, using fallback")
                NSWorkspace.shared.open(fallback)
            }
        }
    }
}
