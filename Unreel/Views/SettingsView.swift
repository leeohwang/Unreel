import SwiftUI
import WebKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var rulesStore: RulesStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false

    private let limitOptions = [0, 10, 15, 20, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        StatsView(embedded: true)
                    } label: {
                        Label("Your stats", systemImage: "chart.bar")
                    }
                } footer: {
                    Text("How many Reels you skipped and the time you saved. Stored only on this iPhone.")
                }

                Section {
                    Toggle("Block home feed", isOn: $settings.blockFeed)
                } header: {
                    Text("Blocking")
                } footer: {
                    Text("Reels and Explore are always blocked. With the feed blocked, the app opens to your messages.")
                }

                Section {
                    Picker("Daily limit", selection: $settings.dailyLimitMinutes) {
                        ForEach(limitOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "Off" : "\(minutes) min").tag(minutes)
                        }
                    }
                } footer: {
                    Text("After this much time in the app each day, you'll see a reminder to stop.")
                }

                Section {
                    Toggle("Share anonymous stats", isOn: $settings.shareStats)
                } footer: {
                    Text("Once a day, sends a count of how many Reels were blocked, so we can see if Unreel helps people. No account, content or identifier is ever sent.")
                }

                Section {
                    Button("Log out of Instagram", role: .destructive) { confirmLogout = true }
                }

                Section {
                    Link("Privacy policy", destination: Config.privacyPolicyURL)
                    Link("Report a problem", destination: Config.supportURL)
                    LabeledContent("Blocking rules", value: "v\(rulesStore.rules.version)")
                } footer: {
                    Text("Unreel is free and open source. It is not affiliated with, endorsed by, or sponsored by Instagram or Meta.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .confirmationDialog("Log out and clear website data?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Log out", role: .destructive) { logout() }
            } message: {
                Text("Close and reopen the app afterwards.")
            }
        }
    }

    private func logout() {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
    }
}
