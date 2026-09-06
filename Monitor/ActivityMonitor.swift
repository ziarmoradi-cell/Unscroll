import DeviceActivity
import Foundation
import OSLog

final class ActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event.rawValue.hasPrefix("minute-"), let minutes = Int(event.rawValue.dropFirst(7)) else { return }
        do {
            try SharedState.transaction { state in
                guard state.identifier == activity.rawValue,
                      let index = state.journal.usage.firstIndex(where: { $0.id == activity.rawValue }) else { return }
                let allocated = state.journal.usage[index].allocatedMinutes
                state.journal.usage[index].confirmedMinutes = max(state.journal.usage[index].confirmedMinutes, min(minutes, allocated))
                if minutes >= allocated { SharedState.finish(&state, reason: "Zeit aufgebraucht. Bereit für eine neue Runde?") }
            }
        } catch {
            Logger(subsystem: "Unscroll", category: "monitor").error("Usage update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        finish(activity, reason: "Testzeitraum abgelaufen. Apps wieder gesperrt.")
    }

    private func finish(_ activity: DeviceActivityName, reason: String) {
        do {
            try SharedState.transaction { state in
                guard state.identifier == activity.rawValue else { return }
                SharedState.finish(&state, reason: reason)
            }
        } catch {
            Logger(subsystem: "com.example.unscroll", category: "monitor").error("Shared state unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }
}
