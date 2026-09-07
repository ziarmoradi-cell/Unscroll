import Foundation

enum PersonalGoal: String, Codable, CaseIterable, Identifiable {
    case lessScroll = "Weniger scrollen", focus = "Mehr Konzentration", sleep = "Besser abschalten", active = "Aktiver leben"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .lessScroll: return "iphone.slash"; case .focus: return "scope"; case .sleep: return "moon.stars"; case .active: return "figure.walk" }
    }
}
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case gentle = "Sanft", balanced = "Ausgewogen", ambitious = "Ambitioniert"
    var id: String { rawValue }
    var stepGoal: Int { self == .gentle ? 4000 : self == .balanced ? 7000 : 10000 }
    var repGoal: Int { self == .gentle ? 10 : self == .balanced ? 20 : 40 }
    var dailyBudget: Int { self == .gentle ? 60 : self == .balanced ? 45 : 30 }
}
struct PersonalProfile: Codable {
    var name = ""
    var age: Int?
    var goal = PersonalGoal.lessScroll
    var difficulty = Difficulty.balanced
    var dailyBudget = 45
    var completedIntro = false
}
struct FocusSession: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date
    var intention: String
    var strict: Bool
    var completed = false
    var interrupted = false
    var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
}
struct DetoxPlan: Codable {
    var start: Date
    var end: Date
    var days: Int
    var hard: Bool
    var dailyLimit: Int { hard ? 0 : 30 }
    func active(at date: Date) -> Bool { date >= start && date < end }
}
struct Wellbeing: Codable {
    var profile = PersonalProfile()
    var stepBlocks: [String: Int] = [:]
    var stepTotals: [String: Int] = [:]
    var redeemedSeconds: [String: Int] = [:]
    var focusSessions: [FocusSession] = []
    var activeFocus: FocusSession?
    var detox: DetoxPlan?
    var nightUntil: Date?
    var routine: [String: Set<String>] = [:]
    var checkedTips: Set<String> = []
    var parkingNote = ""
    var detoxInterrupted = 0
}
extension Ledger {
    var life: Wellbeing {
        get { wellbeing ?? Wellbeing() }
        set { wellbeing = newValue }
    }
    static func dayKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    func restricted(at now: Date = Date()) -> Bool {
        if let p = life.detox, p.hard && p.active(at: now) { return true }
        if let f = life.activeFocus, f.strict && f.end > now { return true }
        return (life.nightUntil ?? .distantPast) > now
    }
    func dailyAvailableSeconds(at now: Date = Date()) -> Int {
        var limit = life.profile.completedIntro ? life.profile.dailyBudget : 120
        if let p = life.detox, p.active(at: now) { limit = min(limit, p.dailyLimit) }
        return max(0, limit * 60 - (life.redeemedSeconds[Self.dayKey(now)] ?? 0))
    }
    @discardableResult mutating func claimSteps(total: Int, day: String) -> Int {
        guard total >= 0 else { return 0 }
        let previous = life.stepBlocks[day] ?? 0
        let next = min(10, total / 1000)
        life.stepTotals[day] = max(total, life.stepTotals[day] ?? 0)
        guard next > previous else { return 0 }
        let earned = (next - previous) * 60
        life.stepBlocks[day] = next; balanceSeconds += earned
        return earned
    }
    mutating func settleFocus(at now: Date = Date()) {
        guard var session = life.activeFocus, session.end <= now else { return }
        session.completed = true
        if !life.focusSessions.contains(where: { $0.id == session.id }) { life.focusSessions.append(session) }
        life.activeFocus = nil
    }
    mutating func abandonFocus(at now: Date = Date()) {
        settleFocus(at: now)
        guard var session = life.activeFocus else { return }
        session.end = now; session.interrupted = true
        life.focusSessions.append(session); life.activeFocus = nil
    }
    func focusMinutes(on date: Date = Date()) -> Int {
        life.focusSessions.filter { $0.completed && Self.dayKey($0.end) == Self.dayKey(date) }.reduce(0) { $0 + $1.minutes }
    }
    var activeDayCount: Int {
        Set(workouts.map { Self.dayKey($0.date) } + life.focusSessions.filter(\.completed).map { Self.dayKey($0.end) } + life.stepBlocks.filter { $0.value > 0 }.map(\.key)).count
    }
}
