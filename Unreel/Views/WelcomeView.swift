import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Text("Social media, minus the scroll")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 18) {
                row("message.fill", "Keep what matters", "Messages, posting, stories and profiles work as usual.")
                row("hand.raised.fill", "Skip the endless feed", "Reels and Explore are blocked. Search still works.")
                row("chart.bar.fill", "See what you skipped", "Your stats stay on your phone. Set a daily limit if you want one.")
            }
            Text("Log in with your usual account. Unreel never sees your password or messages, and it is free with no ads or subscriptions. Not affiliated with Instagram or Meta.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onContinue) {
                Text("Get started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }

    private func row(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}
