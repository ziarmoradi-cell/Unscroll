import Foundation
import FamilyControls
import ManagedSettings

enum ShieldPolicy {
    static let settings = ManagedSettingsStore(named: .init("unscroll"))
    static func block(_ data: Data?) throws {
        guard let data else { return }
        let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }
    static func unblock() { settings.clearAllSettings() }
}
