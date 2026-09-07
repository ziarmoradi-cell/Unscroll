import SwiftUI
import FamilyControls
import DeviceActivity

@MainActor final class ScreenTimeController: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var error: String?
    @Published private(set) var approved = false
    @Published private(set) var grant: UnlockGrant?
    private let center = DeviceActivityCenter()
    init() { refresh() }

    func authorize() async {
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual); refresh() }
        catch { self.error = error.localizedDescription }
    }
    func refresh() {
        approved = AuthorizationCenter.shared.authorizationStatus == .approved
        do {
            try SharedStorage.transaction { ledger in
                if let data = ledger.selectionData { selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data) }
                if let active = ledger.grant, active.expires <= Date() {
                    try ShieldPolicy.block(ledger.selectionData); ledger.finishGrant(active.id)
                }
                grant = ledger.grant
                if grant == nil && approved { try ShieldPolicy.block(ledger.selectionData) }
            }
        } catch { self.error = error.localizedDescription }
    }
    var hasSelection: Bool { !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty }

    func saveSelection() {
        do {
            try SharedStorage.transaction { ledger in
                guard ledger.grant == nil && !ledger.restricted() else { throw ScreenTimeError.active }
                let data = try JSONEncoder().encode(selection)
                try ShieldPolicy.block(data); ledger.selectionData = data
            }
        } catch { self.error = error.localizedDescription; refresh() }
    }

    func unlock(minutes: Int) {
        guard approved, hasSelection else { error = "Erlaube Bildschirmzeit und wähle zuerst Apps aus."; return }
        var installedName: DeviceActivityName?
        do {
            // Keep reservation, monitor installation and unshielding under the same
            // cross-process lock so a concurrent extension cannot expire a new grant.
            try SharedStorage.transaction { ledger in
                guard let reserved = ledger.reserve(minutes: minutes) else { throw ScreenTimeError.balance }
                let name = DeviceActivityName(reserved.id)
                let calendar = Calendar.current
                let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
                let schedule = DeviceActivitySchedule(
                    intervalStart: calendar.dateComponents(components, from: Date()),
                    intervalEnd: calendar.dateComponents(components, from: reserved.expires), repeats: false)
                let event = DeviceActivityEvent(applications: selection.applicationTokens,
                    categories: selection.categoryTokens, webDomains: selection.webDomainTokens,
                    threshold: DateComponents(minute: minutes), includesPastActivity: false)
                do {
                    // Only one active grant: clean up expired monitors to avoid the OS limit.
                    center.stopMonitoring()
                    try center.startMonitoring(name, during: schedule, events: [.init("budget"): event])
                    installedName = name
                    ShieldPolicy.unblock()
                } catch {
                    center.stopMonitoring([name]); ledger.cancelFailedReservation(reserved.id)
                    try ShieldPolicy.block(ledger.selectionData)
                    throw error
                }
            }
        } catch {
            self.error = error.localizedDescription
            // Even a disk-write failure AFTER successful OS setup must fail closed.
            if let installedName {
                center.stopMonitoring([installedName])
                do { try ShieldPolicy.block(JSONEncoder().encode(selection)) }
                catch { self.error = "Freischaltung fehlgeschlagen: \(error.localizedDescription)" }
            }
        }
        refresh()
    }

    func blockNow() {
        do {
            try SharedStorage.transaction { ledger in
                try ShieldPolicy.block(ledger.selectionData)
                if let id = ledger.grant?.id { ledger.finishGrant(id) }
            }
            center.stopMonitoring()
        } catch { self.error = error.localizedDescription }
        refresh()
    }
}

private enum ScreenTimeError: LocalizedError {
    case balance, active
    var errorDescription: String? {
        switch self {
        case .balance: return "Freischaltung nicht möglich: Prüfe Guthaben, Tageslimit und aktive Pausen."
        case .active: return "Beende zuerst die Freischaltung oder die aktive Pause, bevor du die App-Auswahl änderst."
        }
    }
}
