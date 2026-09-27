import Combine
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    @Bindable var preferences: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    @State private var loginItemError: String?

    private let didBecomeActive = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if loginItemNeedsApproval {
                    Text("Approve horita under System Settings > General > Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items Settings\u{2026}") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
                if let loginItemError {
                    Text(loginItemError).font(.caption).foregroundStyle(.red)
                }
                KeyboardShortcuts.Recorder("Join next meeting", name: .joinNext)
            }
            Section {
                Stepper(value: $preferences.thresholdMinutes, in: Preferences.thresholdRange, step: 5) {
                    Text("Show countdown within: \(preferences.thresholdMinutes) min")
                }
                Stepper(value: $preferences.titleMaxLength, in: Preferences.titleLengthRange, step: 5) {
                    Text("Max title length: \(preferences.titleMaxLength)")
                }
                Toggle(isOn: $preferences.hideTitle) {
                    Text("Hide meeting title")
                    Text("Useful when screen sharing.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshLoginItemStatus)
        .onReceive(didBecomeActive) { _ in refreshLoginItemStatus() }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    loginItemError = nil
                } catch {
                    loginItemError = error.localizedDescription
                }
                refreshLoginItemStatus()
            }
        )
    }

    private func refreshLoginItemStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        loginItemNeedsApproval = status == .requiresApproval
    }
}
