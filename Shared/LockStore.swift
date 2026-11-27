import FamilyControls
import Foundation
import ManagedSettings

/// Screen Time lock on the real Instagram app, shared by the app and its two
/// extensions (shield screen, shield buttons) through an App Group.
///
/// - The user picks the apps to lock (Instagram) with Apple's FamilyActivityPicker;
///   Unreel only ever sees opaque tokens, never which apps they are.
/// - Locked apps still deliver their notifications. Opening one shows Unreel's
///   shield, whose button points back to Unreel. There's no way around it from the
///   shield: posting happens in Unreel.
enum LockStore {
    static let appGroup = "group.com.leeohwang.unreel"

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

}
