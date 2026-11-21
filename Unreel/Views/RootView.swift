import SwiftUI

struct RootView: View {
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var rulesStore: RulesStore
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @StateObject private var navigator = WebNavigator()
    @State private var showSettings = false
    @State private var extendedUntil: Date?
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var limitReached: Bool {
        guard settings.dailyLimitMinutes > 0,
              stats.today.secondsUsed >= settings.dailyLimitMinutes * 60 else { return false }
        if let extendedUntil, extendedUntil > now { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            InstagramWebView(rules: rulesStore.rules, blockFeed: settings.blockFeed, navigator: navigator) { kind, counts in
                if counts { stats.record(kind) }
            }
            .overlay(alignment: .top) {
                // A thin progress line, like Instagram's own, instead of a spinner.
                if navigator.isLoading {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.primary.opacity(0.35))
                            .frame(width: geo.size.width * max(0.05, navigator.progress), height: 2)
                            .animation(.linear(duration: 0.2), value: navigator.progress)
                    }
                    .frame(height: 2)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: navigator.isLoading)
            // Instagram's own bottom bar (with Reels removed) is the main navigation.
            // On pages where Instagram leaves it out (the DM inbox and chats),
            // show ours so there is always a way out.
            if !navigator.igBarVisible {
                Divider()
                TabBar(navigator: navigator, showHome: !settings.blockFeed)
            }
        }
        .overlay {
            if limitReached {
                LimitReachedView(minutes: settings.dailyLimitMinutes) {
                    stats.recordLimitExtension()
                    extendedUntil = Date().addingTimeInterval(5 * 60)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: limitReached)
        .onReceive(tick) { date in
            now = date
            if scenePhase == .active && !limitReached { stats.addUsage(seconds: 1) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stats.save() }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenWelcome }, set: { hasSeenWelcome = !$0 })) {
            WelcomeView { hasSeenWelcome = true }
        }
    }

    /// Laid out like Instagram's header: name on the left, icons on the right.
    private var topBar: some View {
        HStack(spacing: 22) {
            Text("Unreel")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(.primary)
            Spacer()
            if settings.dailyLimitMinutes > 0 {
                Text(remainingText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            // Instagram's mobile bar has no Activity button (it lives on the
            // blocked home feed), so it gets one here.
            Button {
                navigator.lastTappedTab = "activity"
                navigator.go("/accounts/activity/")
            } label: {
                Image(systemName: isOnActivity ? "heart.fill" : "heart")
                    .font(.system(size: 22))
            }
            .accessibilityLabel("Activity")
            Button { showSettings = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22))
            }
            .accessibilityLabel("Settings")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var isOnActivity: Bool {
        navigator.currentPath.hasPrefix("/notifications") || navigator.currentPath.hasPrefix("/accounts/activity")
    }

    private var remainingText: String {
        let left = max(0, settings.dailyLimitMinutes * 60 - stats.today.secondsUsed)
        return left == 0 ? "Limit reached" : "\(Int((Double(left) / 60).rounded(.up))) min left"
    }
}
