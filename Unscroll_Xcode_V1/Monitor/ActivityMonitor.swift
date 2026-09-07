import DeviceActivity
import OSLog

final class ActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if event.rawValue == "budget" { end(activity) }
    }
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        end(activity)
    }
    private func end(_ activity: DeviceActivityName) {
        do {
            try SharedStorage.transaction { ledger in
                // Ignore a delayed callback from an older grant.
                guard ledger.grant?.id == activity.rawValue else { return }
                try ShieldPolicy.block(ledger.selectionData)
                ledger.finishGrant(activity.rawValue)
            }
        } catch {
            Logger(subsystem: "Unscroll", category: "Monitor").error("Unable to restore shield: \(error.localizedDescription, privacy: .public)")
        }
    }
}
