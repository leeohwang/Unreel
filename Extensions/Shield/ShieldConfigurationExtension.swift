import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen people see when they open the locked Instagram app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shield()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shield()
    }

    private func shield() -> ShieldConfiguration {
        let passes = LockStore.passesLeftToday
        let passLabel = String(format: String(localized: "Post something (%lld min)"), LockStore.passMinutes)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            icon: UIImage(systemName: "hand.raised.fill")?.withTintColor(.label, renderingMode: .alwaysOriginal),
            title: .init(text: String(localized: "Locked by Unreel"), color: .label),
            subtitle: .init(text: String(localized: "Your messages are waiting in Unreel, without the Reels."), color: .secondaryLabel),
            primaryButtonLabel: .init(text: String(localized: "Open Unreel"), color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0, green: 0.584, blue: 0.965, alpha: 1),
            secondaryButtonLabel: passes > 0 ? .init(text: passLabel, color: .systemBlue) : nil)
    }
}
