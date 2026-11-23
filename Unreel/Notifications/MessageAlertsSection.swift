import SwiftUI
import UIKit

/// "Message alerts" in Settings. Says plainly that alerts can be late, and points
/// people who need instant alerts to the Screen Time lock just below it.
struct MessageAlertsSection: View {
    @State private var enabled = MessageAlerts.isEnabled
    @State private var showDenied = false
    @State private var refreshStatus = UIApplication.shared.backgroundRefreshStatus

    var body: some View {
        Section {
            Toggle("Alert me about new messages", isOn: Binding(
                get: { enabled },
                set: { on in
                    if on {
                        enabled = true
                        Task {
                            if !(await MessageAlerts.turnOn()) {
                                enabled = false
                                showDenied = true
                            }
                        }
                    } else {
                        enabled = false
                        MessageAlerts.turnOff()
                    }
                }))
            if enabled && refreshStatus != .available {
                Text("Background App Refresh is off for Unreel, so it can't check. Turn it on in the Settings app under General > Background App Refresh.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if enabled, let last = MessageAlerts.lastCheck {
                LabeledContent("Last checked", value: last.formatted(.relative(presentation: .named)))
            }
        } header: {
            Text("Message alerts")
        } footer: {
            Text("Unreel checks your messages when iOS lets it run in the background, so alerts can be an hour or more late, and stop if you swipe Unreel away. The check happens on this iPhone; nothing is sent anywhere. For instant alerts, keep the Instagram app and lock it with Screen Time below.")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.backgroundRefreshStatusDidChangeNotification)) { _ in
            refreshStatus = UIApplication.shared.backgroundRefreshStatus
        }
        .alert("Notifications are off for Unreel", isPresented: $showDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for Unreel in the Settings app to get message alerts.")
        }
    }
}
