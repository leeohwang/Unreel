import DeviceActivity

/// Puts the lock back when a posting pass ends, even if Unreel isn't running.
final class ActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == LockStore.passActivity { LockStore.applyShield() }
    }
}
