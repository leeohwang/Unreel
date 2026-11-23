import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    /// Also send the home feed to your inbox. Reels and Explore are always blocked.
    @Published var blockFeed: Bool { didSet { defaults.set(blockFeed, forKey: Keys.blockFeed) } }

    /// Minutes per day in the app before the "done for today" screen. 0 means no limit.
    @Published var dailyLimitMinutes: Int { didSet { defaults.set(dailyLimitMinutes, forKey: Keys.dailyLimit) } }

    /// Let a Reel a friend sends in a chat play. The Reels tab and swiping on to
    /// more Reels stay blocked.
    @Published var allowDmReels: Bool { didSet { defaults.set(allowDmReels, forKey: Keys.allowDmReels) } }

    /// Send one anonymous summary a day (counts only) to help measure impact.
    @Published var shareStats: Bool { didSet { defaults.set(shareStats, forKey: Keys.shareStats) } }

    init() {
        blockFeed = defaults.object(forKey: Keys.blockFeed) as? Bool ?? true
        dailyLimitMinutes = defaults.object(forKey: Keys.dailyLimit) as? Int ?? 0
        shareStats = defaults.object(forKey: Keys.shareStats) as? Bool ?? true
        allowDmReels = defaults.object(forKey: Keys.allowDmReels) as? Bool ?? true
    }

    enum Keys {
        static let blockFeed = "blockFeed"
        static let dailyLimit = "dailyLimitMinutes"
        static let shareStats = "shareStats"
        static let allowDmReels = "allowDmReels"
    }
}
