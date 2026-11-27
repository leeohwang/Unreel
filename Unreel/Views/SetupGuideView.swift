import AVFoundation
import SwiftUI
import UIKit

/// A short, swipeable how-to: one looping clip and one line per step.
/// Clips are bundled as Resources/Guide/guide-<id>-<n>.mp4 (silent, cut from real
/// screen recordings). A .png of the same name works too; with neither, the step
/// shows a plain placeholder so the guide still reads well.
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
                 detail: "Tap Continue, confirm with Face ID or your passcode, then allow notifications.", symbol: "hourglass"),
            Step(image: "guide-lock-3", title: "Pick Instagram",
                 detail: "Tap Choose Activities, open Social, tick Instagram, then tap Done.", symbol: "checkmark.circle"),
            Step(image: "guide-lock-4", title: "That's it",
                 detail: "The lock is on. Opening Instagram now shows a screen with an Open Unreel button.", symbol: "hand.raised"),
        ]
        case .redirect: [
            Step(image: "guide-redirect-1", title: "Start an automation",
                 detail: "In Shortcuts, tap +. Tap Automation, scroll down and tap App.", symbol: "square.stack.3d.up"),
            Step(image: "guide-redirect-2", title: "Pick Instagram",
                 detail: "In When App is Opened, tap App and choose Instagram.", symbol: "app"),
            Step(image: "guide-redirect-3", title: "Open Unreel",
                 detail: "Add the Open App action, tap App and choose Unreel.", symbol: "arrow.uturn.right"),
            Step(image: "guide-redirect-4", title: "That's it",
                 detail: "Go back to save it. Opening Instagram now takes you to Unreel.", symbol: "checkmark.circle"),
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
                    stepView(steps[index], number: index + 1, isCurrent: index == page).tag(index)
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

    private func stepView(_ step: Step, number: Int, isCurrent: Bool) -> some View {
        VStack(spacing: 18) {
            screenshot(step, isCurrent: isCurrent)
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

    /// The clip or screenshot in a thin phone-like frame, or a placeholder until one is bundled.
    @ViewBuilder
    private func screenshot(_ step: Step, isCurrent: Bool) -> some View {
        if let url = Bundle.main.url(forResource: step.image, withExtension: "mp4") {
            LoopingClip(url: url, isPlaying: isCurrent)
                .aspectRatio(540.0 / 1102.0, contentMode: .fit)
                .modifier(PhoneFrame())
        } else if let image = UIImage(named: step.image) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .modifier(PhoneFrame())
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

private struct PhoneFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .padding(.horizontal, 48)
    }
}

/// A silent clip that loops while its step is on screen and restarts when you come back to it.
/// It has no audio track, so it never interrupts music or other audio.
private struct LoopingClip: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        view.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        guard let player = view.playerLayer.player else { return }
        if isPlaying, player.rate == 0 {
            player.seek(to: .zero)
            player.play()
        } else if !isPlaying, player.rate != 0 {
            player.pause()
        }
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.playerLayer.player?.pause()
        view.looper?.disableLooping()
    }

    final class PlayerView: UIView {
        var looper: AVPlayerLooper?
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
