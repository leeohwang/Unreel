import Foundation

/// Values you fill in once before shipping.
enum Config {
    /// TelemetryDeck app ID from https://dashboard.telemetrydeck.com. Leave empty to turn analytics off.
    static let telemetryDeckAppID = ""

    /// Where the app downloads updated blocking rules. Must be publicly readable.
    /// Edit config/rules.json in the repo (and bump "version") to fix the app without an App Store update.
    static let remoteRulesURL = URL(string: "https://raw.githubusercontent.com/leeohwang/unreel/main/config/rules.json")!

    static let privacyPolicyURL = URL(string: "https://leeohwang.github.io/unreel/privacy")!
    static let supportURL = URL(string: "https://github.com/leeohwang/unreel/issues")!
}
