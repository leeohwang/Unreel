import SwiftUI
import UIKit

/// A short, swipeable how-to: one screenshot and one line per step.
/// Screenshots are bundled as Resources/Guide/guide-<id>-<n>.png; until one exists,
/// the step shows a plain placeholder so the guide still reads well.
struct SetupGuideView: View {
    enum Guide: String, Identifiable {
        case lock, redirect
        var id: String { rawValue }
    }

    struct Step {
        let image: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let symbol: String
    }

    let guide: Guide
    /// Shown as the main button on the last step (e.g. "Open Shortcuts").
    var finishTitle: LocalizedStringKey = "Done"
    var onFinish: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private var title: LocalizedStringKey {
        switch guide {
        case .lock: "Lock the Instagram app"
        case .redirect: "Open Unreel from Instagram"
        }
    }

    private var steps: [Step] {
        switch guide {
        case .lock: [
            Step(image: "guide-lock-1", title: "Turn on the lock",
                 detail: "In Unreel, tap ≡, then turn on Lock the Instagram app.", symbol: "lock"),
            Step(image: "guide-lock-2", title: "Allow Screen Time",
                 detail: "Tap Continue and confirm with Face ID or your passcode.", symbol: "hourglass"),
            Step(image: "guide-lock-3", title: "Pick Instagram",
                 detail: "Tick Instagram in the list, then tap Done.", symbol: "checkmark.circle"),
            Step(image: "guide-lock-4", title: "That's it",
                 detail: "Opening Instagram now shows this screen. Tap Open Unreel, then the notification.", symbol: "hand.raised"),
        ]
        case .redirect: [
            Step(image: "guide-redirect-1", title: "Open Shortcuts",
                 detail: "Go to the Automation tab and tap +.", symbol: "square.stack.3d.up"),
            Step(image: "guide-redirect-2", title: "Choose App",
                 detail: "Pick App from the list.", symbol: "app"),
            Step(image: "guide-redirect-3", title: "Pick Instagram",
                 detail: "Choose Instagram, Is Opened and Run Immediately. Tap Next.", symbol: "checkmark.circle"),
            Step(image: "guide-redirect-4", title: "Open Unreel",
                 detail: "Tap New Blank Automation, add Open App, choose Unreel, then Done.", symbol: "arrow.uturn.right"),
        ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("Close")
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            TabView(selection: $page) {
                ForEach(steps.indices, id: \.self) { index in
                    stepView(steps[index], number: index + 1).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .padding(.vertical, 16)

            Button {
                if page < steps.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                    dismiss()
                }
            } label: {
                Text(page < steps.count - 1 ? "Next" : finishTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.white)
                    .background(Color(red: 0, green: 0.584, blue: 0.965), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }

    private func stepView(_ step: Step, number: Int) -> some View {
        VStack(spacing: 18) {
            screenshot(step)
                .frame(maxHeight: .infinity)
            VStack(spacing: 6) {
                Text("Step \(number)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(step.title)
                    .font(.system(size: 22, weight: .bold))
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    // Same height on every step so the screenshot doesn't jump while swiping.
                    .lineLimit(3, reservesSpace: true)
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 4)
    }

    /// The screenshot in a thin phone-like frame, or a placeholder until one is bundled.
    @ViewBuilder
    private func screenshot(_ step: Step) -> some View {
        if let image = UIImage(named: step.image) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(.horizontal, 48)
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .overlay(Image(systemName: step.symbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary))
                .padding(.horizontal, 48)
        }
    }
}
