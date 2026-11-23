import Foundation

struct PathRule: Codable, Equatable {
    var pattern: String
    var kind: BlockKind
    /// Where to send the user instead of the default redirect path.
    var redirect: String?
    /// Whether this counts toward "blocked" stats. Defaults to true.
    var count: Bool?
    /// Regex on the previous page's path: when it matches (and the user allows it),
    /// this page is not blocked. Used to let a Reel a friend sent in a chat play.
    var allowFrom: String?
}

struct Rules: Codable, Equatable {
    var version: Int
    var redirectPath: String
    var minutesPerBlockedVisit: Double
    var blockedPaths: [PathRule]
    var hideSelectors: [String]
    var feedSelectors: [String]
    /// Links inside Instagram's own bottom tab bar. cage.js uses them to tell whether that
    /// bar is on screen; the app shows its own tab bar only where it isn't (e.g. DMs).
    /// Optional so older rules files still decode.
    var igBarLinks: [String]?
    /// Extra CSS for cosmetic fixes (e.g. hiding a border). cage.js marks the page
    /// with html[data-unreel-path="…"] so rules can target one page. Optional.
    var extraCSS: String?
    /// Links to single Reels. Hidden everywhere, or everywhere but chats when
    /// Reels friends send may play.
    var reelLinkSelectors: [String]?
    /// Hidden when the home feed is shown (Reel posts in it).
    var filteredFeedSelectors: [String]?
    /// Labels of suggested / sponsored posts (several languages), hidden from the feed.
    var feedHideTextMarkers: [String]?
    /// Instagram's create-menu labels ("Post", "Story") in the languages we know.
    var createLabels: [String: [String]]?

    /// The first rule that blocks this path, honoring the settings and, for rules
    /// with `allowFrom`, the page the user is coming from.
    func match(path: String, blockFeed: Bool, fromPath: String? = nil, allowDmReels: Bool = false) -> PathRule? {
        blockedPaths.first { rule in
            if rule.kind == .feed && !blockFeed { return false }
            guard Self.matches(rule.pattern, path) else { return false }
            if allowDmReels, let allowFrom = rule.allowFrom, let fromPath, Self.matches(allowFrom, fromPath) {
                return false
            }
            return true
        }
    }

    private static func matches(_ pattern: String, _ string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
    }

    static let bundled: Rules = {
        guard let url = Bundle.main.url(forResource: "rules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(Rules.self, from: data) else {
            fatalError("rules.json is missing or invalid")
        }
        return rules
    }()
}

/// Loads blocking rules: bundled defaults, overridden by a newer remote copy.
@MainActor
final class RulesStore: ObservableObject {
    @Published private(set) var rules: Rules
    private var lastFetch: Date?

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rules.json")
    }

    init() {
        var current = Rules.bundled
        if let data = try? Data(contentsOf: Self.cacheURL),
           let cached = try? JSONDecoder().decode(Rules.self, from: data),
           cached.version > current.version {
            current = cached
        }
        rules = current
    }

    /// Fetches the remote rules each time the app comes to the foreground (at most
    /// every 5 minutes). A newer version is applied to the open page right away.
    func refresh() async {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 300 { return }
        lastFetch = Date()
        var request = URLRequest(url: Config.remoteRulesURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        guard let remote = try? JSONDecoder().decode(Rules.self, from: data),
              remote.blockedPaths.allSatisfy({ (try? NSRegularExpression(pattern: $0.pattern)) != nil })
        else {
            // A rules file we published that this build can't read: worth knowing fast.
            Analytics.breakage("rules-invalid", rulesVersion: rules.version)
            return
        }
        guard remote.version > rules.version else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
        rules = remote
    }
}
