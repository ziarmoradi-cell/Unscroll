import Foundation

struct WorkoutEntry: Codable, Identifiable {
    var id: UUID
    var date: Date
    var exercise: Exercise
    var reps: Int
    var plankSeconds: Double
    var bestHold: Double
    var creditedSeconds: Int
}

struct UnlockGrant: Codable {
    var id: String
    var seconds: Int
    var expires: Date
}

struct Ledger: Codable {
    var balanceSeconds = 0
    var records: [String: Double] = [:]
    var workouts: [WorkoutEntry] = []
    var grant: UnlockGrant?
    var selectionData: Data?
    var migrated = false
    var pushUpSeconds = 30
    var squatSeconds = 30

    func record(_ exercise: Exercise) -> Double { records[exercise.rawValue] ?? 0 }

    mutating func checkpoint(id: UUID, exercise: Exercise, progress: WorkoutProgress, rewardPerRep: Int, now: Date = Date()) {
        guard progress.reps >= 0, progress.plankSeconds.isFinite, progress.plankSeconds >= 0,
              progress.bestHold.isFinite, progress.bestHold >= 0 else { return }
        let reward = exercise == .plank ? Int(floor(progress.plankSeconds / 10)) * 60 : progress.reps * max(0, rewardPerRep)
        let previous = workouts.first(where: { $0.id == id })
        // A delayed UI callback must never lower an already persisted checkpoint.
        guard previous == nil || (previous!.exercise == exercise && reward >= previous!.creditedSeconds && progress.reps >= previous!.reps && progress.plankSeconds >= previous!.plankSeconds) else { return }
        balanceSeconds += max(0, reward - (previous?.creditedSeconds ?? 0))
        records[exercise.rawValue] = max(record(exercise), exercise == .plank ? progress.bestHold : Double(progress.reps))
        let entry = WorkoutEntry(id: id, date: previous?.date ?? now, exercise: exercise, reps: progress.reps,
                                 plankSeconds: progress.plankSeconds, bestHold: progress.bestHold, creditedSeconds: reward)
        if let index = workouts.firstIndex(where: { $0.id == id }) { workouts[index] = entry }
        else if reward > 0 || progress.bestHold > 0 || progress.reps > 0 { workouts.append(entry) }
    }

    mutating func reserve(minutes: Int, now: Date = Date()) -> UnlockGrant? {
        guard grant == nil, minutes > 0, minutes <= 120, balanceSeconds >= minutes * 60 else { return nil }
        let new = UnlockGrant(id: UUID().uuidString, seconds: minutes * 60, expires: now.addingTimeInterval(24 * 3600))
        balanceSeconds -= new.seconds
        grant = new
        return new
    }

    mutating func cancelFailedReservation(_ id: String) {
        guard let current = grant, current.id == id else { return }
        balanceSeconds += current.seconds; grant = nil
    }

    mutating func finishGrant(_ id: String) {
        guard grant?.id == id else { return }
        grant = nil
    }
}
