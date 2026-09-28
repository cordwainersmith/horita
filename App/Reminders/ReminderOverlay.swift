import AppKit
import SwiftUI
import HoritaCore

/// Borderless and non-activating, so it takes the keyboard (Return, S, Esc) without having to activate the app.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class ReminderOverlay {
    struct Actions {
        let join: (Event) -> Void
        let snooze: ([Event]) -> Void
    }

    private var panel: OverlayPanel?
    private var shown: [Event] = []
    private var screenObserver: NSObjectProtocol?

    var isShowing: Bool { panel != nil }

    func show(_ events: [Event], actions: Actions) {
        let merged = shown + events.filter { event in !shown.contains { $0.id == event.id } }
        close()
        shown = merged

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.frame else { return }

        let panel = OverlayPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.autoresizingMask = [.width, .height]

        let view = ReminderOverlayView(
            events: merged,
            join: { [weak self] event in
                self?.close()
                actions.join(event)
            },
            snooze: { [weak self] in
                self?.close()
                actions.snooze(merged)
            },
            dismiss: { [weak self] in self?.close() }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)
        panel.contentView = background

        panel.setFrame(frame, display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        self.panel = panel

        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.keepOnScreen() }
        }
    }

    func close() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        panel?.orderOut(nil)
        panel = nil
        shown = []
    }

    // If the display the overlay was on goes away, move it to the main display.
    private func keepOnScreen() {
        guard let panel else { return }
        if NSScreen.screens.contains(where: { $0.frame == panel.frame }) { return }
        guard let frame = NSScreen.main?.frame else { return }
        panel.setFrame(frame, display: true)
    }
}

private struct ReminderOverlayView: View {
    let events: [Event]
    let join: (Event) -> Void
    let snooze: () -> Void
    let dismiss: () -> Void

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 28) {
                ForEach(events) { event in
                    card(event, now: context.date)
                }
                HStack(spacing: 12) {
                    Button(action: dismiss) {
                        Label("Dismiss", systemImage: "xmark")
                    }
                    .keyboardShortcut(.cancelAction)
                    Button(action: snooze) {
                        Label("Snooze", systemImage: "clock.arrow.circlepath")
                    }
                    .keyboardShortcut("s", modifiers: [])
                    if let first = events.first {
                        Button { join(first) } label: {
                            Label("Join", systemImage: "video")
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .controlSize(.large)
                Text("Return to join \u{00B7} S to snooze until it starts \u{00B7} Esc to dismiss")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func card(_ event: Event, now: Date) -> some View {
        VStack(spacing: 10) {
            Text(TitleFormatter.truncate(event.title, maxLength: 80))
                .font(.system(size: 34, weight: .semibold))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(nsColor: NSColor(hex: event.calendarColorHex) ?? .systemGray))
                    .frame(width: 10, height: 10)
                Text(clock(for: event, now: now) + " \u{00B7} " + event.calendarTitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if events.count > 1 {
                Button("Join") { join(event) }
            }
        }
    }

    private func clock(for event: Event, now: Date) -> String {
        event.start > now
            ? TitleFormatter.countdown(until: event.start, now: now)
            : TitleFormatter.remaining(until: event.end, now: now)
    }
}
