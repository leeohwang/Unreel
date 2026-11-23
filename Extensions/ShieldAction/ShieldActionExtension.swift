import ManagedSettings
import UserNotifications

/// What the shield's buttons do.
/// - "Open Unreel": an extension can't open another app, so it posts a
///   notification that opens Unreel on your messages when tapped.
/// - "Post something": a 5-minute posting pass (twice a day).
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ done: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Open Unreel")
            content.body = String(localized: "Tap to see your messages.")
            content.userInfo = ["path": "/direct/inbox/"]
            let request = UNNotificationRequest(identifier: "unreel.open", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in done(.close) }
        case .secondaryButtonPressed:
            // .defer redraws the shield; with the pass started, it is gone.
            done(LockStore.startPass() ? .defer : .none)
        @unknown default:
            done(.close)
        }
    }
}
