import AppKit
import os
import SwiftUI

@MainActor @Observable
final class SettingsState {
    var tab: SettingsTab = .general
    var twinNotice: String?
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let state: SettingsState
    private let preferences: Preferences
    private var hasShown = false
    private let log = Logger(subsystem: "dev.liranbaba.Horita", category: "ui")

    init(model: AppModel, preferences: Preferences, eventKit: EventKitSource, repository: EventRepository, checkForUpdates: @escaping () -> Void) {
        let state = SettingsState()
        self.state = state
        self.preferences = preferences

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "horita Settings")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsRoot(state: state, model: model, preferences: preferences, eventKit: eventKit, repository: repository, checkForUpdates: checkForUpdates)
        )
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(tab: SettingsTab) {
        state.tab = tab
        if !hasShown {
            window?.center()
            hasShown = true
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Cooperative activation may be refused; the window must still become visible.
        window?.orderFrontRegardless()
        log.info("settings shown")
    }

    func windowWillClose(_ notification: Notification) {
        if !preferences.hasCompletedFirstRun {
            preferences.hasCompletedFirstRun = true
            log.info("first run completed")
        }
    }
}

struct SettingsRoot: View {
    @Bindable var state: SettingsState
    let model: AppModel
    let preferences: Preferences
    let eventKit: EventKitSource
    let repository: EventRepository
    let checkForUpdates: () -> Void

    var body: some View {
        TabView(selection: $state.tab) {
            GeneralTab(preferences: preferences)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            CalendarsTab(state: state, model: model, preferences: preferences, eventKit: eventKit, repository: repository)
                .tabItem { Label("Calendars", systemImage: "calendar") }
                .tag(SettingsTab.calendars)
            AboutTab(checkForUpdates: checkForUpdates)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 520, height: 420)
    }
}
