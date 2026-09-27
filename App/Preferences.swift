import Foundation
import Observation
import HoritaCore

@MainActor @Observable
final class Preferences {
    private enum Key {
        static let thresholdMinutes = "thresholdMinutes"
        static let titleMaxLength = "titleMaxLength"
        static let hideTitle = "hideTitle"
        static let enabledCalendarKeys = "enabledCalendarKeys"
        static let hasCompletedFirstRun = "hasCompletedFirstRun"
        static let lastEventKitCalendarIDs = "lastEventKitCalendarIDs"
    }

    static let thresholdRange = 5...240
    static let titleLengthRange = 10...60

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onCalendarSelectionChanged: (() -> Void)?

    private var thresholdStorage: Int
    private var titleLengthStorage: Int
    private var hideTitleStorage: Bool
    private var enabledKeysStorage: Set<String>
    private var firstRunStorage: Bool
    private var lastEventKitIDsStorage: [String]

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

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
