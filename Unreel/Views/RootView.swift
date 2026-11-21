import SwiftUI

struct RootView: View {
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var rulesStore: RulesStore
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @StateObject private var navigator = WebNavigator()
    @State private var showSettings = false
    @State private var pickingFor: WebNavigator.CreateKind?
    /// Where you left off last time, shown until Instagram paints (see WebNavigator.saveSnapshot).
    @State private var launchSnapshot = UIImage(contentsOfFile: WebNavigator.snapshotURL.path)
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
            // No divider under the header: Instagram's pages start with their
            // own header row, so the two read as one header, as in the app.
            topBar
            InstagramWebView(rules: rulesStore.rules, blockFeed: settings.blockFeed,
                             allowDmReels: settings.allowDmReels, navigator: navigator) { kind, counts in
                if counts { stats.record(kind) }
            }
            .overlay(alignment: .top) {
                if !navigator.hasPainted, let launchSnapshot {
                    Image(uiImage: launchSnapshot)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .clipped()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: navigator.hasPainted)
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
            .overlay {
                // Covers the home feed that Instagram's create flow starts from.
                if navigator.isCreating {
                    ZStack {
                        navigator.pageBackground
                        ProgressView()
                    }
                }
            }
            // Instagram's own bottom bar (with Reels removed) is the main navigation.
            // On pages where Instagram leaves it out (the DM inbox and chats),
            // show ours so there is always a way out.
            if !navigator.igBarVisible {
                Rectangle()
                    .fill(Color(uiColor: .pageSeparator))
                    .frame(height: 1)
                TabBar(navigator: navigator, showHome: !settings.blockFeed)
            }
        }
        // Status bar, home indicator and overscroll areas take the page's colour.
        .background(navigator.pageBackground.ignoresSafeArea())
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
            if phase == .inactive { navigator.saveSnapshot() }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $pickingFor) { kind in
            PhotoPicker { jpeg in
                pickingFor = nil
                if let jpeg { navigator.create(kind, jpeg: jpeg) }
            }
            .ignoresSafeArea()
        }
        .alert("Couldn't open Instagram's editor", isPresented: $navigator.createFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Instagram may have changed its page. Try again in a moment.")
        }
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
            // Instagram's "+" (Post / Story) sits on its home feed header, which
            // is blocked, so it gets one here too.
            Menu {
                Button { pickingFor = .post } label: { Label("Post", systemImage: "square.grid.3x3") }
                Button { pickingFor = .story } label: { Label("Story", systemImage: "plus.circle.dashed") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24))
            }
            .accessibilityLabel("Create")
            // Instagram's mobile bar has no Activity button (it lives on the
            // blocked home feed), so it gets one here.
            Button {
                navigator.lastTappedTab = "activity"
                navigator.go("/accounts/activity/")
            } label: {
                Image(systemName: isOnActivity ? "heart.fill" : "heart")
                    .font(.system(size: 24))
            }
            .accessibilityLabel("Activity")
            Button { showSettings = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24))
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

extension WebNavigator.CreateKind: Identifiable {
    var id: String { rawValue }
}
