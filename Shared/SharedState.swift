import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Darwin

struct Session: Codable {
    var selection = FamilyActivitySelection()
    var identifier: String?
    var expiresAt: Date?
    var emergencyCount = 0
    var status = "Apps auswählen und sperren."
    var journal = Journal()
}

enum SharedState {
    // Must match both targets' App Group entitlement.
    static let group = Bundle.main.object(forInfoDictionaryKey: "UnscrollAppGroup") as? String ?? "group.com.example.unscroll"
    static let settings = ManagedSettingsStore(named: .init("unscroll"))

    // Serializes app/extension access, including shield changes.
    static func transaction<T>(_ body: (inout Session) throws -> T) throws -> T {
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw NSError(domain: "Unscroll", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group fehlt. Bitte die Signierung beider Targets prüfen."])
        }
        let fd = open(folder.appendingPathComponent("state.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(fd, LOCK_UN) }
        let url = folder.appendingPathComponent("state-v2.json")
        var state = Session()
        if FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(Session.self, from: Data(contentsOf: url))
        }
        let result = try body(&state)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
        return result
    }

    static func shield(_ state: Session) {
        settings.shield.applications = state.selection.applicationTokens.isEmpty ? nil : state.selection.applicationTokens
    }

    static func finish(_ state: inout Session, reason: String) {
        shield(state)
        if let index = state.journal.usage.firstIndex(where: { $0.id == state.identifier }) {
            state.journal.usage[index].end = Date()
        }
        state.identifier = nil
        state.expiresAt = nil
        state.status = reason
    }
}
