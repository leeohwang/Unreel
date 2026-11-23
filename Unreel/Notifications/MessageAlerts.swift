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
    nonisolated static let taskID = "com.leeohwang.unreel.messagecheck"

    private static let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "messageAlertsEnabled"
        static let alerted = "messageAlertsAlerted"          // [String]: chat + last message we alerted about
        static let lastCount = "messageAlertsLastCount"      // Int: unread count at the last check
        static let hasBaseline = "messageAlertsHasBaseline"  // Bool: first check done
        static let lastCheck = "messageAlertsLastCheck"      // Date
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
        // The first check only notes what's already unread, so turning this on
        // doesn't set off a burst of alerts about old messages.
        defaults.set(false, forKey: Keys.hasBaseline)
        schedule()
        return true
    }

    static func turnOff() {
        defaults.set(false, forKey: Keys.enabled)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: Background refresh

    /// Must run before the app finishes launching.
    nonisolated static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: .main) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            MainActor.assumeIsolated { handle(task) }
        }
    }

    /// Asks iOS for the next check. 15 minutes is the earliest we ask for;
    /// iOS usually waits longer.
    static func schedule() {
        guard isEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Expected in the Simulator, which doesn't run app refresh tasks.
            #if DEBUG
            print("Message alerts: couldn't schedule a check:", error)
            #endif
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        let probe = InboxProbe()
        task.expirationHandler = { Task { @MainActor in probe.cancel() } }
        Task { @MainActor in
            let found = await check(using: probe)
            task.setTaskCompleted(success: found)
        }
    }

    // MARK: The check

    /// Reads the inbox and posts alerts. Returns whether the page could be read.
    @discardableResult
    static func check(using probe: InboxProbe? = nil, debug: Bool = false) async -> Bool {
        guard isEnabled || debug else { return false }
        // Default arguments are evaluated outside the main actor, so make the probe here.
        let probe = probe ?? InboxProbe()
        let rules = RulesStore.saved().inbox ?? .fallback
        guard let result = await probe.run(rules: rules, timeout: debug ? 60 : 25, debug: debug) else {
            if debug { writeDebugNote("probe returned nil (timed out, page failed to load, or result didn't decode)") }
            Analytics.breakage("inbox-timeout", rulesVersion: RulesStore.saved().version)
            return false
        }
        if debug { writeDebugDump(result) }
        guard result.loggedIn else { return false }
        guard result.listFound else {
            // Instagram changed its inbox page; new rules can fix this without an update.
            Analytics.breakage("inbox-unreadable", rulesVersion: RulesStore.saved().version)
            return false
        }
        defaults.set(Date(), forKey: Keys.lastCheck)
        await process(result, debug: debug)
        return true
    }

    private static func process(_ result: InboxProbe.Result, debug: Bool) async {
        // Debug runs always alert, so a test right after turning alerts on shows a banner.
        let isBaseline = !defaults.bool(forKey: Keys.hasBaseline) && !debug
        defaults.set(true, forKey: Keys.hasBaseline)

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

        guard !isBaseline else { return }
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
            let ok = await check(debug: true)
            writeDebugNote("background check finished, read page: \(ok), app state: \(UIApplication.shared.applicationState.rawValue) (2 = background)", append: true)
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
    /// Read it with `xcrun simctl get_app_container booted com.leeohwang.unreel data`.
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
