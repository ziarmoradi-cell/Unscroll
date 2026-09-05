import Foundation

enum Exercise: String, Codable, CaseIterable, Identifiable {
    case pushups, squats, plank, situps
    var id: String { rawValue }
    var title: String { switch self { case .pushups: "Liegestütze"; case .squats: "Squats"; case .plank: "Plank"; case .situps: "Sit-ups" } }
    var symbol: String { switch self { case .pushups: "figure.strengthtraining.functional"; case .squats: "figure.strengthtraining.traditional"; case .plank: "figure.core.training"; case .situps: "figure.cooldown" } }
    var unit: String { self == .plank ? "Sekunden" : "Wiederholungen" }
}

struct Profile: Codable {
    var name = ""
    var birthday = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    var configured = false
    var dailyGoal = 20
    var minutesPerRep = 1
    var plankSecondsPerMinute = 10
    var eveningHour = 21
    var wakeHour = 7
    var wakeMinute = 0
    var leaderboardConsent = false
    var age: Int { max(0, Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0) }
}

struct Workout: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var exercise: Exercise
    var amount: Int
    var earnedMinutes: Int
}

struct UsageSession: Codable, Identifiable {
    var id: String
    var start: Date
    var end: Date?
    var allocatedMinutes: Int
    var confirmedMinutes = 0
    var emergency: Bool
    var started = false
}

struct Journal: Codable {
    var profile = Profile()
    var bank = 0
    var workouts: [Workout] = []
    var usage: [UsageSession] = []
    var challengeStart: Date?

    mutating func record(_ workout: Workout) -> Bool {
        guard workout.amount > 0, workout.earnedMinutes >= 0,
              !workouts.contains(where: { $0.id == workout.id }) else { return false }
        workouts.append(workout)
        bank += workout.earnedMinutes
        return true
    }

    func reward(exercise: Exercise, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        return exercise == .plank ? amount / max(1, profile.plankSecondsPerMinute) : amount * max(1, profile.minutesPerRep)
    }

    func week(at date: Date = Date(), calendar: Calendar = .current) -> [Workout] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return workouts.filter { interval.contains($0.date) }
    }

    func streak(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(workouts.filter { $0.amount > 0 }.map { calendar.startOfDay(for: $0.date) })
        var cursor = calendar.startOfDay(for: date)
        if !days.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor)! }
        var total = 0
        while days.contains(cursor) {
            total += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return total
    }

    func challengeDays(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let start = challengeStart else { return 0 }
        let end = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: start))!
        return Set(workouts.filter { $0.date >= start && $0.date < end && $0.date <= date }.map { calendar.startOfDay(for: $0.date) }).count
    }
}

// Geometry-independent state machine, shared by Vision input and deterministic tests.
struct RepetitionCounter {
    enum Position { case ready, contracted, moving, invalid }
    private(set) var count = 0
    private var armed = false
    private var contracted = false
    private var stableFrames = 0
    private var previous: Position = .invalid
    private var lastTime: Double?
    private var cycleStart = 0.0

    mutating func resetTracking() {
        armed = false; contracted = false; stableFrames = 0; previous = .invalid; lastTime = nil
    }

    mutating func update(_ position: Position, at time: Double) {
        if let lastTime, time - lastTime > 0.7 || time < lastTime { resetTracking() }
        lastTime = time
        guard position != .invalid else { resetTracking(); return }
        if position == .moving { stableFrames = 0; previous = .moving; return }
        if position == previous { stableFrames += 1 } else { stableFrames = 1; previous = position }
        guard stableFrames >= 3 else { return }
        if position == .ready {
            if armed && contracted && time - cycleStart >= 0.7 {
                count += 1; contracted = false
            }
            if !armed { cycleStart = time }
            armed = true
        } else if armed && !contracted {
            contracted = true
            cycleStart = time
        }
    }
}

struct HoldCounter {
    private(set) var seconds = 0.0
    private var previous: Double?
    mutating func update(valid: Bool, at time: Double) {
        defer { previous = valid ? time : nil }
        guard valid, let previous else { return }
        let delta = time - previous
        if delta > 0 && delta < 0.7 { seconds += delta }
    }
}
