import Foundation

struct PathRule: Codable, Equatable {
    var pattern: String
    var kind: BlockKind
    /// Where to send the user instead of the default redirect path.
    var redirect: String?
    /// Whether this counts toward "blocked" stats. Defaults to true.
    var count: Bool?
}

struct Rules: Codable, Equatable {
    var version: Int
    var redirectPath: String
    var minutesPerBlockedVisit: Double
    var blockedPaths: [PathRule]
    var hideSelectors: [String]
    var feedSelectors: [String]

    /// The first rule that blocks this path, honoring the feed setting.
    func match(path: String, blockFeed: Bool) -> PathRule? {
        blockedPaths.first { rule in
            if rule.kind == .feed && !blockFeed { return false }
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { return false }
            return regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
        }
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

    /// Fetches the remote rules at most once an hour.
    func refresh() async {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 3600 { return }
        lastFetch = Date()
        var request = URLRequest(url: Config.remoteRulesURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let remote = try? JSONDecoder().decode(Rules.self, from: data),
              remote.version > rules.version,
              remote.blockedPaths.allSatisfy({ (try? NSRegularExpression(pattern: $0.pattern)) != nil })
        else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
        rules = remote
    }
}
