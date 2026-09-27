import AppKit
import Observation
import os

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let buildMenu: () -> NSMenu
    private let join: () -> Void
    private let menuWillOpen: () -> Void
    private var lastRender: AppModel.StatusRender?
    private let titleFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    private let log = Logger(subsystem: "dev.liranbaba.Horita", category: "ui")

    init(model: AppModel, buildMenu: @escaping () -> NSMenu, join: @escaping () -> Void, menuWillOpen: @escaping () -> Void) {
        self.model = model
        self.buildMenu = buildMenu
        self.join = join
        self.menuWillOpen = menuWillOpen
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        observe()
    }

    // Observation tracking is one-shot and its onChange fires on willSet, so the
    // re-render is hopped onto the main actor (after the mutation) and re-registers.
    private func observe() {
        let render = withObservationTracking {
            model.statusRender
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
        apply(render)
    }

    private func apply(_ render: AppModel.StatusRender) {
        guard render != lastRender, let button = statusItem.button else { return }
        lastRender = render

        let image = NSImage(systemSymbolName: render.iconName, accessibilityDescription: "horita")?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        image?.isTemplate = true
        button.image = image

        if let text = render.text {
            button.attributedTitle = NSAttributedString(string: text, attributes: [.font: titleFont])
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
        button.setAccessibilityLabel(render.accessibilityLabel)
        let size = image?.size ?? .zero
        log.debug("status item rendered: hasText=\(render.text != nil) icon=\(render.iconName, privacy: .public) image=\(size.width)x\(size.height) frame=\(String(describing: button.window?.frame), privacy: .public) visible=\(self.statusItem.isVisible)")
    }

    @objc private func clicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if secondary {
            join()
            return
        }
        menuWillOpen()
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    // Assigning the menu only for the duration of the click is what lets right-click act differently.
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }
}
