import FamilyControls
import SwiftUI
import UserNotifications

/// The Settings side of the Screen Time lock (see Shared/LockStore.swift).
@MainActor
final class LockModel: ObservableObject {
    @Published private(set) var enabled = LockStore.isEnabled
    @Published var selection = LockStore.selection ?? FamilyActivitySelection() {
        didSet {
            LockStore.selection = selection
            LockStore.applyShield()
        }
    }
    @Published var showPicker = false
    @Published var errorText: String?

    var hasApps: Bool { !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty }

    /// Asks for Screen Time access (Face ID / passcode), then for notification
    /// permission, then shows Apple's app picker so the user can choose Instagram.
    func turnOn() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorText = String(localized: "Screen Time access wasn't allowed. You can try again, or turn it on in the Settings app under Screen Time.")
            return
        }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        LockStore.isEnabled = true
        enabled = true
        if hasApps { LockStore.applyShield() } else { showPicker = true }
    }

    func turnOff() {
        LockStore.isEnabled = false
        enabled = false
        LockStore.clearShield()
    }

    /// Re-applies the lock on launch, so it is on even if an older version left it
    /// lifted for a posting pass (that pass no longer exists).
    static func restoreOnLaunch() {
        guard LockStore.isEnabled, AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        LockStore.applyShield()
    }
}
