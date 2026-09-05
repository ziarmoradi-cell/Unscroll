import XCTest
@testable import UnscrollCore

final class DomainTests: XCTestCase {
    func testRewardAndDuplicateCompletion() {
        var journal = Journal()
        XCTAssertEqual(journal.reward(exercise: .pushups, amount: 10), 20)
        XCTAssertEqual(journal.reward(exercise: .plank, amount: 29), 0)
        let workout = Workout(exercise: .pushups, amount: 10, earnedMinutes: 10)
        XCTAssertTrue(journal.record(workout))
        XCTAssertFalse(journal.record(workout))
        XCTAssertEqual(journal.bank, 10)
    }

    func testRoundTripPreservesBankAndWorkoutIdentity() throws {
        var journal = Journal()
        _ = journal.record(Workout(exercise: .squats, amount: 7, earnedMinutes: 7))
        let restored = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
        XCTAssertEqual(restored.bank, 7)
        XCTAssertEqual(restored.workouts.first?.id, journal.workouts.first?.id)
    }

    func testFullCycleRequired() {
        var counter = RepetitionCounter()
        for i in 0..<10 { counter.update(.contracted, at: Double(i) * 0.1) }
        XCTAssertEqual(counter.count, 0)
        for i in 10..<14 { counter.update(.ready, at: Double(i) * 0.1) }
        for i in 14..<25 { counter.update(.contracted, at: Double(i) * 0.1) }
        for i in 25..<29 { counter.update(.ready, at: Double(i) * 0.1) }
        XCTAssertEqual(counter.count, 1)
        for i in 29..<40 { counter.update(.ready, at: Double(i) * 0.1) }
        XCTAssertEqual(counter.count, 1)
    }

    func testLostTrackingDoesNotCompleteRep() {
        var counter = RepetitionCounter()
        for i in 0..<4 { counter.update(.ready, at: Double(i) * 0.1) }
        for i in 4..<8 { counter.update(.contracted, at: Double(i) * 0.1) }
        counter.update(.invalid, at: 0.8)
        for i in 9..<20 { counter.update(.ready, at: Double(i) * 0.1) }
        XCTAssertEqual(counter.count, 0)
    }

    func testSlowContinuousMovementPreservesCycle() {
        var counter = RepetitionCounter()
        for i in 0..<4 { counter.update(.ready, at: Double(i) * 0.1) }
        for i in 4..<24 { counter.update(.moving, at: Double(i) * 0.1) }
        for i in 24..<28 { counter.update(.contracted, at: Double(i) * 0.1) }
        for i in 28..<48 { counter.update(.moving, at: Double(i) * 0.1) }
        for i in 48..<52 { counter.update(.ready, at: Double(i) * 0.1) }
        XCTAssertEqual(counter.count, 1)
    }

    func testHoldDoesNotCountCameraGap() {
        var counter = HoldCounter()
        counter.update(valid: true, at: 0)
        counter.update(valid: true, at: 0.2)
        counter.update(valid: false, at: 0.3)
        counter.update(valid: true, at: 30)
        counter.update(valid: true, at: 30.2)
        XCTAssertEqual(counter.seconds, 0.4, accuracy: 0.001)
    }

    func testStreakSurvivesTodayBeforeWorkout() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        var journal = Journal()
        for day in [1, 2, 3] {
            _ = journal.record(Workout(date: calendar.date(byAdding: .day, value: -day, to: today)!, exercise: .squats, amount: 1, earnedMinutes: 1))
        }
        XCTAssertEqual(journal.streak(at: today, calendar: calendar), 3)
    }
}
