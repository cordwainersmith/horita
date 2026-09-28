import AppKit
import KeyboardShortcuts
import HoritaCore

@main @MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var preferences: Preferences!
    private var model: AppModel!
    private var statusItemController: StatusItemController!
    private var eventKit: EventKitSource!
    private var repository: EventRepository!
    private var ticker: MinuteTicker!
    private var lifecycle: LifecycleObserver!
    private var settings: SettingsWindowController!
    private var updater: Updater!
    private var reminders: ReminderController!

    // With no storyboard, AppKit's default @main entry point never instantiates
    // the delegate, so applicationDidFinishLaunching would never run.
    private static var retainedDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        preferences = Preferences()
        model = AppModel(preferences: preferences)
        statusItemController = StatusItemController(
            model: model,
            buildMenu: { [unowned self] in MenuBuilder.build(model: model, actions: menuActions()) },
            join: { [unowned self] in join(model.joinTarget) },
            menuWillOpen: { [unowned self] in repository.refresh(reason: .menuOpened) }
        )
        eventKit = EventKitSource()
        repository = EventRepository(model: model, sources: [eventKit], preferences: preferences)
        reminders = ReminderController(model: model, preferences: preferences, join: { [unowned self] in join($0) })
        ticker = MinuteTicker(model: model)
        lifecycle = LifecycleObserver(repository: repository, ticker: ticker)
        updater = Updater()
        settings = SettingsWindowController(
            model: model, preferences: preferences, eventKit: eventKit, repository: repository,
            checkForUpdates: { [unowned self] in updater.checkForUpdates() }
        )

        repository.start()
        ticker.start()
        reminders.start()

        KeyboardShortcuts.onKeyUp(for: .joinNext) { [unowned self] in
            join(model.joinTarget)
        }

        if !preferences.hasCompletedFirstRun {
            Task { @MainActor [settings] in settings!.show(tab: .calendars) }
        }
    }

    /// Every join path goes through here, so a meeting joined early doesn't get a reminder.
    private func join(_ event: Event?) {
        Joiner.join(event)
        if let event {
            reminders.markJoined(event)
        }
    }

    private func menuActions() -> MenuActions {
        MenuActions(
            join: { [unowned self] in join($0) },
            copyLink: { url in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            },
            openURL: { NSWorkspace.shared.open($0) },
            setMuted: { [unowned self] event, muted in preferences.setMuted(event.muteKey, muted: muted) },
            openSettings: { [unowned self] tab in settings.show(tab: tab) },
            checkForUpdates: { [unowned self] in updater.checkForUpdates() },
            quit: { NSApp.terminate(nil) }
        )
    }

    // An LSUIElement app has no visible menu bar, but without a main menu the
    // standard Edit key equivalents (⌘C, ⌘V, ⌘A) do not reach text fields in
    // the Settings window.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit horita", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
