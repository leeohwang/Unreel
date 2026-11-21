import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Screen Time lock on the real Instagram app, shared by the app and its three
/// extensions (shield screen, shield buttons, activity monitor) through an App Group.
///
/// - The user picks the apps to lock (Instagram) with Apple's FamilyActivityPicker;
///   Unreel only ever sees opaque tokens, never which apps they are.
/// - Locked apps still deliver their notifications. Opening one shows Unreel's
///   shield, whose button points back to Unreel.
/// - Twice a day the shield offers a 5-minute posting pass, for what Instagram's
///   website can't do (videos, music).
enum LockStore {
    static let appGroup = "group.com.leeohwang.unreel"
    static let passesPerDay = 2
    static let passMinutes = 5
    static let passActivity = DeviceActivityName("unreel.postingPass")

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
    private static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("unreel"))

    static var isEnabled: Bool {
        get { defaults.bool(forKey: "lock.enabled") }
        set { defaults.set(newValue, forKey: "lock.enabled") }
    }

    static var selection: FamilyActivitySelection? {
        get {
            defaults.data(forKey: "lock.selection")
                .flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }
        }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "lock.selection") }
    }

    /// Shields the chosen apps (and categories). Web domains are left alone on
    /// purpose: shielding instagram.com would also block Unreel's own web view.
    static func applyShield() {
        guard isEnabled, let selection else { return clearShield() }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }

    static func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    // MARK: Posting passes

    private static var today: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static var passesLeftToday: Int {
        let used = defaults.string(forKey: "lock.passDay") == today ? defaults.integer(forKey: "lock.passesUsed") : 0
        return max(0, passesPerDay - used)
    }

    /// Lifts the shield for `passMinutes`; the activity monitor puts it back.
    /// DeviceActivity only accepts windows of 15 minutes or more, so the window
    /// starts 10 minutes in the past and ends `passMinutes` from now.
    @discardableResult
    static func startPass() -> Bool {
        guard isEnabled, passesLeftToday > 0 else { return false }
        let now = Date()
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: now.addingTimeInterval(-10 * 60)),
            intervalEnd: Calendar.current.dateComponents(parts, from: now.addingTimeInterval(Double(passMinutes) * 60)),
            repeats: false)
        let center = DeviceActivityCenter()
        center.stopMonitoring([passActivity])
        do { try center.startMonitoring(passActivity, during: schedule) } catch { return false }
        let used = passesPerDay - passesLeftToday
        defaults.set(today, forKey: "lock.passDay")
        defaults.set(used + 1, forKey: "lock.passesUsed")
        clearShield()
        return true
    }
}
