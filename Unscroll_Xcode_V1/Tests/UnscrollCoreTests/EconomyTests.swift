import XCTest
@testable import UnscrollCore

final class EconomyTests: XCTestCase {
    func testPlankTenSecondBoundaryAndIdempotentSave() {
        var ledger = Ledger(); let id = UUID()
        var p = WorkoutProgress(); p.plankSeconds = 9.99; p.bestHold = 9.99
        ledger.checkpoint(id: id, exercise: .plank, progress: p, rewardPerRep: 30)
        XCTAssertEqual(ledger.balanceSeconds, 0)
        p.plankSeconds = 10; p.bestHold = 10
        for _ in 0..<5 { ledger.checkpoint(id: id, exercise: .plank, progress: p, rewardPerRep: 30) }
        XCTAssertEqual(ledger.balanceSeconds, 60)
        p.plankSeconds = 29.9; p.bestHold = 15
        ledger.checkpoint(id: id, exercise: .plank, progress: p, rewardPerRep: 30)
        XCTAssertEqual(ledger.balanceSeconds, 120); XCTAssertEqual(ledger.record(.plank), 15)
        XCTAssertEqual(ledger.workouts.count, 1)
    }
    func testRecordsAreSeparateAndNeverDecrease() throws {
        var ledger = Ledger(); var p = WorkoutProgress(); p.reps = 12
        ledger.checkpoint(id: UUID(), exercise: .pushUps, progress: p, rewardPerRep: 30)
        p.reps = 4; ledger.checkpoint(id: UUID(), exercise: .pushUps, progress: p, rewardPerRep: 30)
        p.reps = 20; ledger.checkpoint(id: UUID(), exercise: .squats, progress: p, rewardPerRep: 30)
        let restored = try JSONDecoder().decode(Ledger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored.record(.pushUps), 12); XCTAssertEqual(restored.record(.squats), 20)
        XCTAssertEqual(restored.balanceSeconds, 1080)
    }
    func testNoOverspendAndFailedSetupRefundsOnlyOnce() {
        var ledger = Ledger(); ledger.balanceSeconds = 300
        XCTAssertNil(ledger.reserve(minutes: 6)); XCTAssertNil(ledger.reserve(minutes: 0))
        let grant = ledger.reserve(minutes: 5)!
        XCTAssertEqual(ledger.balanceSeconds, 0); XCTAssertNil(ledger.reserve(minutes: 1))
        ledger.cancelFailedReservation(grant.id); ledger.cancelFailedReservation(grant.id)
        XCTAssertEqual(ledger.balanceSeconds, 300)
    }
    func testStaleCallbackCannotExpireNewGrant() {
        var ledger = Ledger(); ledger.balanceSeconds = 600
        let old = ledger.reserve(minutes: 1)!; ledger.finishGrant(old.id)
        let current = ledger.reserve(minutes: 2)!
        ledger.finishGrant(old.id); ledger.cancelFailedReservation(old.id)
        XCTAssertEqual(ledger.grant?.id, current.id); XCTAssertEqual(ledger.balanceSeconds, 420)
    }
    func testStaleCheckpointCannotDoubleCredit() {
        var ledger = Ledger(); let id = UUID(); var p = WorkoutProgress(); p.reps = 10
        ledger.checkpoint(id: id, exercise: .pushUps, progress: p, rewardPerRep: 30)
        p.reps = 5; ledger.checkpoint(id: id, exercise: .pushUps, progress: p, rewardPerRep: 30)
        p.reps = 10; ledger.checkpoint(id: id, exercise: .pushUps, progress: p, rewardPerRep: 30)
        XCTAssertEqual(ledger.balanceSeconds, 300); XCTAssertEqual(ledger.workouts.first?.reps, 10)
    }
}
