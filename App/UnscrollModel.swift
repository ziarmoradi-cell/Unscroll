import SwiftUI
import FamilyControls
import DeviceActivity

@MainActor
final class UnscrollModel: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var state = Session()
    @Published var authorized = false
    @Published var error: String?
    var active: Bool { state.identifier != nil }

    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        do {
            state = try SharedState.transaction { state in
                if let expiry = state.expiresAt, expiry <= Date() {
                    SharedState.finish(&state, reason: "Nutzungsfenster beendet. Apps sind gesperrt.")
                }
                return state
            }
            selection = state.selection
        } catch { self.error = error.localizedDescription }
    }

    func authorize() async {
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual); refresh() }
        catch { self.error = error.localizedDescription }
    }

    func saveSelection() {
        guard authorized else { return }
        guard !selection.applicationTokens.isEmpty, selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty else {
            error = "Bitte einzelne Apps auswählen, keine ganzen Kategorien oder Websites."; return
        }
        mutate { state in
            guard state.identifier == nil else { return }
            state.selection = self.selection
            SharedState.finish(&state, reason: "Apps gesperrt. Verdiene jetzt deine Zeit.")
        }
    }

    func saveProfile(_ profile: Profile) {
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              profile.birthday <= Date(), (1...200).contains(profile.dailyGoal) else {
            error = "Bitte Namen, Geburtsdatum und gültige Ziele eintragen."; return
        }
        mutate { state in state.journal.profile = profile; state.journal.profile.configured = true }
    }

    func record(exercise: Exercise, amount: Int, id: UUID) {
        guard amount > 0 else { return }
        mutate { state in
            let reward = state.journal.reward(exercise: exercise, amount: amount)
            let workout = Workout(id: id, exercise: exercise, amount: amount, earnedMinutes: reward)
            if state.journal.record(workout) { state.status = "Geschafft: +\(reward) Minuten auf deinem Zeitkonto." }
        }
    }

    func mutate(_ body: (inout Session) throws -> Void) {
        do { try SharedState.transaction(body); refresh() }
        catch { self.error = error.localizedDescription }
    }

    func start(emergency: Bool = false) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            error = "Bitte zuerst Bildschirmzeit-Zugriff erlauben."; return
        }
        let identifier = UUID().uuidString
        let start = Date()
        let expiry = start.addingTimeInterval(23 * 60 * 60)
        do {
            let prepared = try SharedState.transaction { state in
                guard state.identifier == nil, !state.selection.applicationTokens.isEmpty else {
                    throw Self.problem("Zuerst Apps auswählen. Eine laufende Sitzung muss beendet sein.")
                }
                let budget = emergency ? 5 : min(30, state.journal.bank)
                guard budget > 0 else { throw Self.problem("Dein Zeitkonto ist leer. Starte eine Übung.") }
                state.identifier = identifier; state.expiresAt = expiry
                if !emergency { state.journal.bank -= budget }
                state.journal.usage.append(UsageSession(id: identifier, start: start, allocatedMinutes: budget, emergency: emergency))
                state.status = "\(budget) gemeinsame Nutzungsminuten vorbereitet."
                return (state.selection.applicationTokens, budget)
            }
            let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let schedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(fields, from: start),
                intervalEnd: Calendar.current.dateComponents(fields, from: expiry), repeats: false
            )
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for minute in 1...prepared.1 {
                events[.init("minute-\(minute)")] = DeviceActivityEvent(applications: prepared.0, threshold: DateComponents(minute: minute), includesPastActivity: false)
            }
            let center = DeviceActivityCenter()
            center.stopMonitoring(center.activities.filter { $0.rawValue != identifier })
            try center.startMonitoring(.init(identifier), during: schedule, events: events)
            try SharedState.transaction { state in
                guard state.identifier == identifier,
                      let index = state.journal.usage.firstIndex(where: { $0.id == identifier }) else { return }
                state.journal.usage[index].started = true
                if emergency { state.emergencyCount += 1 }
                state.status = "\(prepared.1) Minuten freigegeben – für alle ausgewählten Apps."
                SharedState.settings.shield.applications = nil
            }
            refresh()
        } catch {
            DeviceActivityCenter().stopMonitoring([.init(identifier)])
            do {
                try SharedState.transaction { state in
                    if state.identifier == identifier {
                        if let index = state.journal.usage.firstIndex(where: { $0.id == identifier }), !state.journal.usage[index].started {
                            if !state.journal.usage[index].emergency { state.journal.bank += state.journal.usage[index].allocatedMinutes }
                            state.journal.usage.remove(at: index)
                        }
                        SharedState.finish(&state, reason: "Freigabe fehlgeschlagen. Apps bleiben gesperrt.")
                    }
                }
            } catch { self.error = "Speicherfehler: \(error.localizedDescription)"; return }
            refresh(); self.error = error.localizedDescription
        }
    }

    func stop(removeRestrictions: Bool = false) {
        do {
            let identifier = try SharedState.transaction { state in
                let previous = state.identifier
                SharedState.finish(&state, reason: removeRestrictions ? "Unscroll-Sperren entfernt." : "Sitzung beendet. Apps gesperrt.")
                if removeRestrictions { SharedState.settings.clearAllSettings(); state.selection = FamilyActivitySelection() }
                return previous
            }
            if let identifier { DeviceActivityCenter().stopMonitoring([.init(identifier)]) }
            refresh()
        } catch { self.error = error.localizedDescription }
    }

    nonisolated static func problem(_ message: String) -> NSError {
        NSError(domain: "Unscroll", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
