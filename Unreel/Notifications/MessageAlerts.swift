import BackgroundTasks
import UIKit
import UserNotifications

/// Best-effort alerts for new Instagram messages, done entirely on the phone.
///
/// iOS decides when Background App Refresh runs: usually a few times a day for an app
/// you open often, never if you swipe the app away, turn on Low Power Mode or turn
/// Background App Refresh off. So alerts can be late. Settings says so, and points
/// people who need instant alerts to the Screen Time lock of the real Instagram app.
///
/// Each check opens the inbox invisibly (InboxProbe) and posts a local notification
/// for each unread chat with a last message we haven't alerted about yet.
/// Nothing is sent anywhere: what we've alerted about is kept on the phone only.
@MainActor
enum MessageAlerts {
    nonisolated static let taskID = "com.leeohwang.unreelapp.messagecheck"
    /// A second, longer chance to check while the phone is charging (usually overnight).
    /// iOS tends to grant these more readily than app refresh to an app it has little history for.
    nonisolated static let chargingTaskID = "com.leeohwang.unreelapp.messagecheck.charging"

    private static let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "messageAlertsEnabled"
        static let alerted = "messageAlertsAlerted"          // [String]: chat + last message we alerted about
        static let lastCount = "messageAlertsLastCount"      // Int: unread count at the last check
        static let lastCheck = "messageAlertsLastCheck"      // Date
        static let lastBackgroundRun = "messageAlertsLastBackgroundRun"      // Date: iOS last ran our task
        static let lastBackgroundResult = "messageAlertsLastBackgroundResult" // String: what that run found
        static let backgroundRuns = "messageAlertsBackgroundRuns"            // Int
    }

    /// What iOS's last background run of the check did, for Settings. nil if iOS hasn't run it yet.
    static var lastBackgroundRun: (date: Date, result: String, count: Int)? {
        guard let date = defaults.object(forKey: Keys.lastBackgroundRun) as? Date else { return nil }
        return (date, defaults.string(forKey: Keys.lastBackgroundResult) ?? "", defaults.integer(forKey: Keys.backgroundRuns))
    }

    static var isEnabled: Bool { defaults.bool(forKey: Keys.enabled) }
    static var lastCheck: Date? { defaults.object(forKey: Keys.lastCheck) as? Date }

    /// You've opened the app, so the icon's unread number is out of date.
    static func appBecameActive() {
        guard isEnabled else { return }
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: Turning it on and off

    /// Asks for notification permission, then starts checking. Returns false if
    /// notifications weren't allowed.
    static func turnOn() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        defaults.set(true, forKey: Keys.enabled)
        schedule()
        return true
    }

    static func turnOff() {
        defaults.set(false, forKey: Keys.enabled)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: chargingTaskID)
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: Background refresh

    /// Must run before the app finishes launching.
    nonisolated static func register() {
        for id in [taskID, chargingTaskID] {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { task in
                MainActor.assumeIsolated { handle(task) }
            }
        }
    }

    /// Asks iOS for the next check. 15 minutes is the earliest we ask for;
    /// iOS usually waits longer.
    static func schedule() {
        guard isEnabled else { return }
        let refresh = BGAppRefreshTaskRequest(identifier: taskID)
        refresh.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        let charging = BGProcessingTaskRequest(identifier: chargingTaskID)
        charging.requiresExternalPower = true
        charging.requiresNetworkConnectivity = true
        charging.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        for request in [refresh, charging] as [BGTaskRequest] {
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                // Expected in the Simulator, which doesn't run background tasks.
                #if DEBUG
                print("Message alerts: couldn't schedule \(request.identifier):", error)
                #endif
            }
        }
    }

    private static func handle(_ task: BGTask) {
        schedule()
        let probe = InboxProbe()
        task.expirationHandler = { Task { @MainActor in probe.cancel() } }
        Task { @MainActor in
            let outcome = await check(using: probe)
            // Recorded so Settings can show whether iOS is running the check at all.
            defaults.set(Date(), forKey: Keys.lastBackgroundRun)
            defaults.set(outcome.rawValue, forKey: Keys.lastBackgroundResult)
            defaults.set(defaults.integer(forKey: Keys.backgroundRuns) + 1, forKey: Keys.backgroundRuns)
            task.setTaskCompleted(success: outcome == .read)
        }
    }

    enum Outcome: String {
        case read, off, timedOut, loggedOut, pageChanged
    }

    // MARK: The check

    /// Reads the inbox and posts alerts.
    @discardableResult
    static func check(using probe: InboxProbe? = nil, debug: Bool = false) async -> Outcome {
        guard isEnabled || debug else { return .off }
        // Default arguments are evaluated outside the main actor, so make the probe here.
        let probe = probe ?? InboxProbe()
        let rules = RulesStore.saved().inbox ?? .fallback
        guard let result = await probe.run(rules: rules, timeout: debug ? 60 : 25, debug: debug) else {
            if debug { writeDebugNote("probe returned nil (timed out, page failed to load, or result didn't decode)") }
            Analytics.breakage("inbox-timeout", rulesVersion: RulesStore.saved().version)
            return .timedOut
        }
        if debug { writeDebugDump(result) }
        guard result.loggedIn else { return .loggedOut }
        guard result.listFound else {
            // Instagram changed its inbox page; new rules can fix this without an update.
            Analytics.breakage("inbox-unreadable", rulesVersion: RulesStore.saved().version)
            return .pageChanged
        }
        defaults.set(Date(), forKey: Keys.lastCheck)
        await process(result)
        return .read
    }

    // No "first check is a baseline" rule: when iOS runs the first check can be hours
    // after alerts were turned on, and skipping it silently lost real messages.
    // At most 5 alerts per check keeps a first run with old unread chats reasonable.
    private static func process(_ result: InboxProbe.Result) async {
        var alerted = Set(defaults.stringArray(forKey: Keys.alerted) ?? [])
        let lastCount = defaults.integer(forKey: Keys.lastCount)
        let count = result.unreadCount ?? 0
        defaults.set(count, forKey: Keys.lastCount)
        try? await UNUserNotificationCenter.current().setBadgeCount(count)

        var fresh: [InboxProbe.Chat] = []
        for chat in result.threads {
            let key = "\(chat.id ?? chat.name)|\(chat.preview ?? "")"
            if alerted.insert(key).inserted { fresh.append(chat) }
        }
        // Forget chats that are read now, so the list doesn't grow forever.
        let unreadKeys = Set(result.threads.map { "\($0.id ?? $0.name)|\($0.preview ?? "")" })
        alerted = alerted.intersection(unreadKeys)
        defaults.set(Array(alerted), forKey: Keys.alerted)

        if !fresh.isEmpty {
            for chat in fresh.prefix(5) { post(chat) }
        } else if result.threads.isEmpty, count > lastCount {
            // The page gave a count but no rows we could read.
            post(nil, count: count)
        }
    }

    private static func post(_ chat: InboxProbe.Chat?, count: Int = 1) {
        let content = UNMutableNotificationContent()
        if let chat {
            content.title = chat.name
            content.body = chat.preview ?? String(localized: "Sent you a message")
            content.threadIdentifier = chat.id ?? chat.name
            content.userInfo = ["path": chat.id.map { "/direct/t/\($0)/" } ?? "/direct/inbox/"]
        } else {
            content.title = String(localized: "New messages")
            content.body = String(localized: "You have \(count) unread chats")
            content.userInfo = ["path": "/direct/inbox/"]
        }
        content.sound = .default
        let id = "message-" + (chat?.id ?? chat?.name ?? "count") + "-\(Int(Date().timeIntervalSince1970))"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    #if DEBUG
    /// Debug: with `-UnreelCheckInBackground`, runs one real check 5 seconds after the app
    /// goes to the background, with the app already backgrounded, to show the invisible web
    /// view still loads and alerts there. (iOS's own refresh scheduling can only be seen on a device.)
    static func debugCheckInBackgroundIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-UnreelCheckInBackground") else { return }
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "debug-message-check")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            let outcome = await check(debug: true)
            writeDebugNote("background check finished: \(outcome.rawValue), app state: \(UIApplication.shared.applicationState.rawValue) (2 = background)", append: true)
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
    #endif

    private static func writeDebugNote(_ note: String, append: Bool = false) {
        #if DEBUG
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("inbox-probe.txt")
        let old = append ? ((try? String(contentsOf: url, encoding: .utf8)) ?? "") + "\n" : ""
        try? (old + "\(Date())\n\(note)\n").write(to: url, atomically: true, encoding: .utf8)
        #endif
    }

    /// Debug builds: what the last check saw, so the selectors can be tuned.
    /// Read it with `xcrun simctl get_app_container booted com.leeohwang.unreelapp data`.
    private static func writeDebugDump(_ result: InboxProbe.Result) {
        #if DEBUG
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var text = "path: \(result.path)\nloggedIn: \(result.loggedIn)\nlistFound: \(result.listFound)\n"
        text += "rows: \(result.rowCount)\ntitleCount: \(String(describing: result.titleCount))\n"
        text += "badgeCount: \(String(describing: result.badgeCount))\nunread: \(result.threads)\n\n"
        text += result.outline ?? ""
        try? text.write(to: dir.appendingPathComponent("inbox-probe.txt"), atomically: true, encoding: .utf8)
        #endif
    }
}
