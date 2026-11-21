import SwiftUI

/// First-run onboarding: three short pages, styled plainly like Instagram's own.
/// 1. What's blocked and what still works. 2. Your login stays yours.
/// 3. A few choices (all changeable later in Settings).
struct WelcomeView: View {
    @EnvironmentObject private var settings: AppSettings
    let onContinue: () -> Void

    @State private var page = 0
    private let limitOptions = [0, 15, 30, 45, 60]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                whatItDoes.tag(0)
                yourLogin.tag(1)
                choices.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    onContinue()
                }
            } label: {
                Text(page < 2 ? "Next" : "Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled()
    }

    // MARK: Pages

    private var whatItDoes: some View {
        pageLayout(title: "Instagram, minus the scroll") {
            row("message", "Messages, posts and stories", "Chat, post photos and stories, search and visit profiles as usual.")
            row("hand.raised", "No Reels, no Explore", "The endless video feed and the Explore grid are blocked.")
            row("play.rectangle", "Reels friends send still play", "Open a Reel from a chat and it plays. Swiping to more Reels takes you back.")
        }
    }

    private var yourLogin: some View {
        pageLayout(title: "Your account stays yours") {
            row("lock", "Log in on Instagram's own page", "Unreel never sees your password or your messages.")
            row("iphone", "Your stats stay on your phone", "How many Reels you skipped is counted on this iPhone only.")
            row("gift", "Free for everyone", "No ads, no subscription, no sign-up.")
            Text("Not affiliated with Instagram or Meta.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var choices: some View {
        pageLayout(title: "Make it yours") {
            Toggle(isOn: $settings.blockFeed) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block home feed").font(.headline)
                    Text("Open straight to your messages.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $settings.allowDmReels) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Play Reels friends send").font(.headline)
                    Text("Only the one they sent, nothing after it.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily limit").font(.headline)
                    Text("A reminder to stop after this long.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Daily limit", selection: $settings.dailyLimitMinutes) {
                    ForEach(limitOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? "Off" : "\(minutes) min").tag(minutes)
                    }
                }
                .labelsHidden()
            }
            Text("You can change these any time in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: Building blocks

    private func pageLayout<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 24)
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 20) { content() }
            Spacer(minLength: 56) // room for the page dots
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
