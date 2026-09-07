import SwiftUI

@MainActor final class AppStore: ObservableObject {
    @Published private(set) var ledger = Ledger()
    @Published var error: String?
    init() {
        reload()
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            mutate { ledger in
                ledger = Ledger(); ledger.migrated = true
                if !ProcessInfo.processInfo.arguments.contains("--ui-screen=onboarding") {
                    ledger.life.profile.name = "Alex"; ledger.life.profile.completedIntro = true
                }
            }
        }
        #endif
    }
    func mutate(_ change: (inout Ledger) -> Void) {
        do { ledger = try SharedStorage.transaction { change(&$0); return $0 } }
        catch { self.error = error.localizedDescription }
    }
    func settle() { mutate { $0.settleFocus() } }
    func claimSteps(_ snapshot: StepSnapshot) {
        mutate { $0.claimSteps(total: snapshot.total, day: snapshot.day) }
    }
    func reload() {
        do {
            ledger = try SharedStorage.transaction { ledger in
                if !ledger.migrated {
                    ledger.balanceSeconds += max(0, UserDefaults.standard.integer(forKey: "earnedMinutes")) * 60
                    ledger.migrated = true
                }
                return ledger
            }
        } catch { self.error = error.localizedDescription }
    }
    func checkpoint(id: UUID, exercise: Exercise, progress: WorkoutProgress, reward: Int) {
        do {
            ledger = try SharedStorage.transaction {
                $0.checkpoint(id: id, exercise: exercise, progress: progress, rewardPerRep: reward); return $0
            }
        } catch { self.error = error.localizedDescription }
    }
    func setRewards(pushUps: Int, squats: Int) {
        do {
            ledger = try SharedStorage.transaction {
                $0.pushUpSeconds = min(120, max(15, pushUps)); $0.squatSeconds = min(120, max(15, squats)); return $0
            }
        } catch { self.error = error.localizedDescription }
    }
}
