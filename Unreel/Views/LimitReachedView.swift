import SwiftUI

struct LimitReachedView: View {
    let minutes: Int
    let onExtend: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("That's your \(minutes) minutes for today")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Your limit resets at midnight. Close the app and go do something you'll remember.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("I need 5 more minutes", action: onExtend)
                .buttonStyle(.bordered)
                .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
