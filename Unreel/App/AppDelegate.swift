import SwiftUI
import UserNotifications

/// Opens Unreel on the right page when one of its notifications is tapped
/// (the Screen Time shield's "Open Unreel" button posts one that points at your messages).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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
