import Foundation
import TelemetryDeck

/// Anonymous impact analytics. At most one signal per user per day, so the
/// TelemetryDeck free tier (50k signals/month) covers roughly 1,600 daily users.
/// Nothing about Instagram content, accounts or messages is ever sent.
@MainActor
enum Analytics {
    private static var started = false
    private static let lastSentKey = "lastSummaryDay"

    private static func startIfNeeded() -> Bool {
        if started { return true }
        guard !Config.telemetryDeckAppID.isEmpty else { return false }
        let config = TelemetryDeck.Config(appID: Config.telemetryDeckAppID)
        // Don't spend the event budget on automatic session signals; App Store Connect already counts users.
        config.sendNewSessionBeganSignal = false
        TelemetryDeck.initialize(config: config)
        started = true
        return true
    }

    /// Anonymous "Instagram changed something and the app broke" signal (e.g. the
    /// create button or Instagram's bar wasn't found, or redirects loop). At most
    /// once per kind per day per device, so it stays well inside the event budget.
    static func breakage(_ what: String, rulesVersion: Int) {
        guard UserDefaults.standard.object(forKey: AppSettings.Keys.shareStats) as? Bool ?? true,
              startIfNeeded() else { return }
        let key = "breakageSent." + what
        let today = StatsStore.key(for: Date())
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        TelemetryDeck.signal("Unreel.breakage", parameters: [
            "what": String(what.prefix(40)),
            "rulesVersion": String(rulesVersion),
            "appVersion": version,
        ])
    }

    /// Sends a summary of the most recent finished day that hasn't been sent yet.
    static func sendDailySummaryIfNeeded(stats: StatsStore, settings: AppSettings, rules: Rules) {
        guard settings.shareStats, startIfNeeded() else { return }
        let todayKey = StatsStore.key(for: Date())
        let lastSent = UserDefaults.standard.string(forKey: lastSentKey) ?? ""
        // Day keys are yyyy-MM-dd, so string comparison is date order.
        guard let (dayKey, day) = stats.days
            .filter({ $0.key < todayKey && $0.key > lastSent })
            .max(by: { $0.key < $1.key }) else { return }

        TelemetryDeck.signal("Unreel.dailySummary", parameters: [
            "reelsBlocked": String(day.reelsBlocked),
            "exploreBlocked": String(day.exploreBlocked),
            "totalBlocked": String(day.totalBlocked),
            "minutesInApp": String(day.secondsUsed / 60),
            "minutesSavedEstimate": String(Int(Double(day.totalBlocked) * rules.minutesPerBlockedVisit)),
            "limitExtensions": String(day.limitExtensions),
            "dailyLimitMinutes": String(settings.dailyLimitMinutes),
            "feedBlocked": String(settings.blockFeed),
        ])
        UserDefaults.standard.set(dayKey, forKey: lastSentKey)
    }
}
