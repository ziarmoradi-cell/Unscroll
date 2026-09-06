import Foundation
import Darwin

enum StorageFailure: LocalizedError {
    case unavailable, locked
    var errorDescription: String? { "Der gemeinsame App-Speicher ist nicht verfügbar. Bitte App-Konfiguration prüfen." }
}

// Shared lock + atomic JSON: no app/extension read-modify-write races.
// Corrupt data is surfaced as an error, never silently reset.
enum SharedStorage {
    static var directory: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "UnscrollAppGroup") as? String else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }
    @discardableResult static func transaction<T>(_ block: (inout Ledger) throws -> T) throws -> T {
        guard let directory else { throw StorageFailure.unavailable }
        let lock = open(directory.appendingPathComponent("ledger.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lock >= 0 else { throw StorageFailure.locked }
        defer { close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw StorageFailure.locked }
        defer { flock(lock, LOCK_UN) }
        let file = directory.appendingPathComponent("ledger.json")
        var ledger: Ledger
        if FileManager.default.fileExists(atPath: file.path) {
            ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: file))
        } else { ledger = Ledger() }
        let result = try block(&ledger)
        try JSONEncoder().encode(ledger).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return result
    }
    static func read() throws -> Ledger { try transaction { $0 } }
}
