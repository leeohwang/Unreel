import SwiftUI

@main
struct UnreelApp: App {
    @StateObject private var stats = StatsStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var rules = RulesStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(stats)
                .environmentObject(settings)
                .environmentObject(rules)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await rules.refresh() }
            Analytics.sendDailySummaryIfNeeded(stats: stats, settings: settings, rules: rules.rules)
        }
    }
}
