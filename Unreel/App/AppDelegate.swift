import SwiftUI
import UserNotifications

/// Opens Unreel on the right page when one of its notifications is tapped
/// (message alerts, and the Screen Time shield's "Open Unreel" button, point at your messages).
/// Also registers the background message check.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        MessageAlerts.register()
        #if DEBUG
        // Debug: `-UnreelCheckMessages` runs one message check right after launch and writes
        // what it saw to Documents/inbox-probe.txt (see MessageAlerts.writeDebugDump).
        if ProcessInfo.processInfo.arguments.contains("-UnreelCheckMessages") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                await MessageAlerts.check(debug: true)
            }
        }
        #endif
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let path = response.notification.request.content.userInfo["path"] as? String
        Task { @MainActor in
            if let path, path.hasPrefix("/") { DeepLink.shared.pendingPath = path }
            completionHandler()
        }
    }
}

/// A page to open once the web view is ready. RootView watches it.
@MainActor
final class DeepLink: ObservableObject {
    static let shared = DeepLink()
    @Published var pendingPath: String?
}
