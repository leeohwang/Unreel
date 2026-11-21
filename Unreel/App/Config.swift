import Foundation

/// Values you fill in once before shipping.
enum Config {
    /// TelemetryDeck app ID from https://dashboard.telemetrydeck.com. Leave empty to turn analytics off.
    static let telemetryDeckAppID = ""

    /// Where the app downloads updated blocking rules. Must be publicly readable.
    /// Edit config/rules.json in the repo (and bump "version") to fix the app without an App Store update.
    static let remoteRulesURL = URL(string: "https://raw.githubusercontent.com/leeohwang/Unreel/main/config/rules.json")!

    static let privacyPolicyURL = URL(string: "https://leeohwang.github.io/Unreel/privacy")!
    static let supportURL = URL(string: "https://github.com/leeohwang/Unreel/issues")!

    /// Where "Report a problem" emails go. Leave empty to open a prefilled GitHub issue instead.
    static let supportEmail = ""

    /// "Report a problem": a prefilled email (or GitHub issue) carrying only the app
    /// version, iOS version and rules version, so problems are easy to place.
    static func reportProblemURL(rulesVersion: Int) -> URL {
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let ios = ProcessInfo.processInfo.operatingSystemVersionString
        let subject = "Unreel problem"
        let body = "What happened?\n\n\nWhat did you expect?\n\n\n---\nUnreel \(app), rules v\(rulesVersion), iOS \(ios)"
        var components: URLComponents
        if supportEmail.isEmpty {
            components = URLComponents(string: "https://github.com/leeohwang/Unreel/issues/new")!
            components.queryItems = [URLQueryItem(name: "title", value: subject), URLQueryItem(name: "body", value: body)]
        } else {
            components = URLComponents()
            components.scheme = "mailto"
            components.path = supportEmail
            components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        }
        return components.url ?? supportURL
    }
}
