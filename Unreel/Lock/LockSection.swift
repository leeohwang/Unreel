import FamilyControls
import SwiftUI

/// "Screen Time" in Settings: lock the real Instagram app so the only way in is Unreel.
struct LockSection: View {
    @StateObject private var lock = LockModel()

    var body: some View {
        Section {
            Toggle("Lock the Instagram app", isOn: Binding(
                get: { lock.enabled },
                set: { on in
                    if on { Task { await lock.turnOn() } } else { lock.turnOff() }
                }))
            if lock.enabled {
                Button(lock.hasApps ? "Change locked apps" : "Choose apps to lock") { lock.showPicker = true }
                LabeledContent("Posting passes left today", value: "\(lock.passesLeft)")
            }
        } header: {
            Text("Screen Time")
        } footer: {
            Text("Opening the locked app shows a screen that points you back here. Its notifications still arrive, so you won't miss messages. Twice a day you can unlock it for 5 minutes to post something the website can't, like a video.")
        }
        .familyActivityPicker(isPresented: $lock.showPicker, selection: $lock.selection)
        .alert("Couldn't turn on the lock", isPresented: Binding(
            get: { lock.errorText != nil }, set: { if !$0 { lock.errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lock.errorText ?? "")
        }
    }
}

/// Offered once, after the app has been used on a couple of days (never at install).
struct LockOfferView: View {
    @StateObject private var lock = LockModel()
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 24)
            Image(systemName: "lock")
                .font(.system(size: 40))
            Text("Make Unreel the only way in")
                .font(.system(size: 30, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Lock the Instagram app with Screen Time. Its notifications still arrive, and opening it points you back to Unreel. Twice a day you can unlock it for 5 minutes to post a video.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                Task {
                    await lock.turnOn()
                    if lock.enabled && lock.hasApps { onDone() }
                }
            } label: {
                Text("Lock it").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            Button("Not now", action: onDone)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .familyActivityPicker(isPresented: $lock.showPicker, selection: $lock.selection)
        .onChange(of: lock.showPicker) { _, showing in
            if !showing && lock.enabled { onDone() }
        }
        .alert("Couldn't turn on the lock", isPresented: Binding(
            get: { lock.errorText != nil }, set: { if !$0 { lock.errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lock.errorText ?? "")
        }
    }
}
