import Foundation
import Observation
import HoritaCore

enum ReminderStyle: String, CaseIterable {
    case off, banner, fullScreen
}

@MainActor @Observable
final class Preferences {
    private enum Key {
        static let thresholdMinutes = "thresholdMinutes"
        static let titleMaxLength = "titleMaxLength"
        static let hideTitle = "hideTitle"
        static let enabledCalendarKeys = "enabledCalendarKeys"
        static let hasCompletedFirstRun = "hasCompletedFirstRun"
        static let lastEventKitCalendarIDs = "lastEventKitCalendarIDs"
        static let mutedSeriesKeys = "mutedSeriesKeys"
        static let reminderStyle = "reminderStyle"
        static let reminderLeadMinutes = "reminderLeadMinutes"
        static let reminderSound = "reminderSound"
    }

    static let thresholdRange = 5...240
    static let titleLengthRange = 10...60
    static let reminderLeadChoices = [1, 2, 5, 10]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onCalendarSelectionChanged: (() -> Void)?

    private var thresholdStorage: Int
    private var titleLengthStorage: Int
    private var hideTitleStorage: Bool
    private var enabledKeysStorage: Set<String>
    private var firstRunStorage: Bool
    private var lastEventKitIDsStorage: [String]
    private var mutedStorage: Set<String>
    private var reminderStyleStorage: ReminderStyle
    private var reminderLeadStorage: Int
    private var reminderSoundStorage: Bool

    /// Calendar key -> twin calendar key. Set by EventRepository after each calendar fetch.
    var twins: [String: String] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        thresholdStorage = Self.clamp(defaults.object(forKey: Key.thresholdMinutes) as? Int ?? 60, to: Self.thresholdRange)
        titleLengthStorage = Self.clamp(defaults.object(forKey: Key.titleMaxLength) as? Int ?? 30, to: Self.titleLengthRange)
        hideTitleStorage = defaults.bool(forKey: Key.hideTitle)
        enabledKeysStorage = Set(defaults.stringArray(forKey: Key.enabledCalendarKeys) ?? [])
        firstRunStorage = defaults.bool(forKey: Key.hasCompletedFirstRun)
        lastEventKitIDsStorage = defaults.stringArray(forKey: Key.lastEventKitCalendarIDs) ?? []
        mutedStorage = Set(defaults.stringArray(forKey: Key.mutedSeriesKeys) ?? [])
        reminderStyleStorage = defaults.string(forKey: Key.reminderStyle).flatMap(ReminderStyle.init(rawValue:)) ?? .off
        reminderLeadStorage = Self.validLead(defaults.object(forKey: Key.reminderLeadMinutes) as? Int)
        reminderSoundStorage = defaults.bool(forKey: Key.reminderSound)
    }

    var thresholdMinutes: Int {
        get { thresholdStorage }
        set {
            thresholdStorage = Self.clamp(newValue, to: Self.thresholdRange)
            defaults.set(thresholdStorage, forKey: Key.thresholdMinutes)
        }
    }

    var titleMaxLength: Int {
        get { titleLengthStorage }
        set {
            titleLengthStorage = Self.clamp(newValue, to: Self.titleLengthRange)
            defaults.set(titleLengthStorage, forKey: Key.titleMaxLength)
        }
    }

    var hideTitle: Bool {
        get { hideTitleStorage }
        set {
            hideTitleStorage = newValue
            defaults.set(newValue, forKey: Key.hideTitle)
        }
    }

    var reminderStyle: ReminderStyle {
        get { reminderStyleStorage }
        set {
            reminderStyleStorage = newValue
            defaults.set(newValue.rawValue, forKey: Key.reminderStyle)
        }
    }

    var reminderLeadMinutes: Int {
        get { reminderLeadStorage }
        set {
            reminderLeadStorage = Self.validLead(newValue)
            defaults.set(reminderLeadStorage, forKey: Key.reminderLeadMinutes)
        }
    }

    var reminderSound: Bool {
        get { reminderSoundStorage }
        set {
            reminderSoundStorage = newValue
            defaults.set(newValue, forKey: Key.reminderSound)
        }
    }

    var hasCompletedFirstRun: Bool {
        get { firstRunStorage }
        set {
            firstRunStorage = newValue
            defaults.set(newValue, forKey: Key.hasCompletedFirstRun)
        }
    }

    var lastEventKitCalendarIDs: [String] {
        get { lastEventKitIDsStorage }
        set {
            lastEventKitIDsStorage = newValue
            defaults.set(newValue, forKey: Key.lastEventKitCalendarIDs)
        }
    }

    var enabledCalendarKeys: Set<String> { enabledKeysStorage }

    /// `Event.muteKey`s the user hid from the menu bar title. Never pruned: events outside the fetch window are unknown.
    var mutedSeriesKeys: Set<String> { mutedStorage }

    func setMuted(_ key: String, muted: Bool) {
        var keys = mutedStorage
        if muted { keys.insert(key) } else { keys.remove(key) }
        guard keys != mutedStorage else { return }
        mutedStorage = keys
        defaults.set(keys.sorted(), forKey: Key.mutedSeriesKeys)
    }

    /// Enables or disables one calendar. Enabling a calendar disables its twin in the same write.
    /// Returns the twin key that was disabled, if any.
    @discardableResult
    func setCalendar(key: String, enabled: Bool) -> String? {
        var keys = enabledKeysStorage
        var disabledTwin: String?
        if enabled {
            keys.insert(key)
            if let twin = twins[key], keys.contains(twin) {
                keys.remove(twin)
                disabledTwin = twin
            }
        } else {
            keys.remove(key)
        }
        guard keys != enabledKeysStorage else { return nil }
        writeEnabledKeys(keys)
        onCalendarSelectionChanged?()
        return disabledTwin
    }

    /// Enables or disables several calendars in one write. Enabling drops their twins, like `setCalendar`.
    func setCalendars(keys: Set<String>, enabled: Bool) {
        var result: Set<String>
        if enabled {
            result = enabledKeysStorage.union(keys)
            for key in keys {
                if let twin = twins[key] { result.remove(twin) }
            }
        } else {
            result = enabledKeysStorage.subtracting(keys)
        }
        guard result != enabledKeysStorage else { return }
        writeEnabledKeys(result)
        onCalendarSelectionChanged?()
    }

    /// Bulk-enables calendars during a refresh (new suggested defaults) without firing the change callback,
    /// since the caller is already mid-refresh and will fetch with the updated set.
    func enableSilently(keys: Set<String>) {
        let merged = enabledKeysStorage.union(keys)
        guard merged != enabledKeysStorage else { return }
        writeEnabledKeys(merged)
    }

    /// Drops keys of `source` calendars that no longer exist.
    func pruneCalendarKeys(source: SourceKind, existing: Set<String>) {
        let prefix = "\(source.rawValue):"
        let kept = enabledKeysStorage.filter { !$0.hasPrefix(prefix) || existing.contains($0) }
        guard kept != enabledKeysStorage else { return }
        writeEnabledKeys(kept)
    }

    private func writeEnabledKeys(_ keys: Set<String>) {
        enabledKeysStorage = keys
        defaults.set(keys.sorted(), forKey: Key.enabledCalendarKeys)
    }

    private static func validLead(_ value: Int?) -> Int {
        value.flatMap { reminderLeadChoices.contains($0) ? $0 : nil } ?? 2
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
