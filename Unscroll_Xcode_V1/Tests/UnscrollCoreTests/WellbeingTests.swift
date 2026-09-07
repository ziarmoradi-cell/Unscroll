import XCTest
@testable import UnscrollCore

final class WellbeingTests: XCTestCase {
    func testReopeningIntroDoesNotBypassDailyLimit() {
        var ledger = Ledger(); ledger.life.profile.dailyBudget = 10
        ledger.life.profile.completedIntro = false
        XCTAssertEqual(ledger.dailyAvailableSeconds(), 600)
    }
    func testStepsNeverDoubleCreditOrExceedDailyCap() {
        var ledger = Ledger()
        XCTAssertEqual(ledger.claimSteps(total: 999, day: "a"), 0)
        XCTAssertEqual(ledger.claimSteps(total: 2500, day: "a"), 120)
        XCTAssertEqual(ledger.claimSteps(total: 2500, day: "a"), 0)
        XCTAssertEqual(ledger.claimSteps(total: 1500, day: "a"), 0)
        XCTAssertEqual(ledger.claimSteps(total: 50000, day: "a"), 480)
        XCTAssertEqual(ledger.claimSteps(total: 2000, day: "b"), 120)
        XCTAssertEqual(ledger.balanceSeconds, 720)
        XCTAssertEqual(ledger.life.stepTotals["a"], 50000)
    }
    func testPreviousLedgerDecodesWithoutLosingProgress() throws {
        let old = #"{"balanceSeconds":420,"records":{"plank":25},"workouts":[],"migrated":true,"pushUpSeconds":30,"squatSeconds":30}"#.data(using: .utf8)!
        let ledger = try JSONDecoder().decode(Ledger.self, from: old)
        XCTAssertEqual(ledger.balanceSeconds, 420)
        XCTAssertEqual(ledger.records["plank"], 25)
        XCTAssertFalse(ledger.life.profile.completedIntro)
    }
    func testBudgetAndFailedReservationRefund() throws {
        var ledger = Ledger(); ledger.balanceSeconds = 10000
        ledger.life.profile.completedIntro = true; ledger.life.profile.dailyBudget = 5
        XCTAssertNil(ledger.reserve(minutes: 6))
        let grant = try XCTUnwrap(ledger.reserve(minutes: 5))
        XCTAssertEqual(ledger.dailyAvailableSeconds(), 0)
        ledger.cancelFailedReservation(grant.id)
        XCTAssertEqual(ledger.balanceSeconds, 10000)
        XCTAssertEqual(ledger.dailyAvailableSeconds(), 300)
        ledger.cancelFailedReservation(grant.id)
        XCTAssertEqual(ledger.balanceSeconds, 10000)
    }
    func testStrictModesRejectRedemptionAndExpire() {
        let now = Date(); var ledger = Ledger(); ledger.balanceSeconds = 600
        ledger.life.activeFocus = FocusSession(start: now, end: now.addingTimeInterval(60), intention: "Read", strict: true)
        XCTAssertNil(ledger.reserve(minutes: 1, now: now))
        ledger.settleFocus(at: now.addingTimeInterval(61))
        ledger.settleFocus(at: now.addingTimeInterval(62))
        XCTAssertEqual(ledger.life.focusSessions.count, 1)
        XCTAssertTrue(ledger.life.focusSessions[0].completed)
        ledger.life.nightUntil = now.addingTimeInterval(60)
        XCTAssertNil(ledger.reserve(minutes: 1, now: now))
        ledger.life.nightUntil = nil
        ledger.life.detox = DetoxPlan(start: now, end: now.addingTimeInterval(60), days: 7, hard: true)
        XCTAssertNil(ledger.reserve(minutes: 1, now: now))
        XCTAssertNotNil(ledger.reserve(minutes: 1, now: now.addingTimeInterval(61)))
    }
    func testInterruptedFocusDoesNotEarnCompletedMinutes() {
        let now = Date(); var ledger = Ledger()
        ledger.life.activeFocus = FocusSession(start: now, end: now.addingTimeInterval(1500), intention: "Read", strict: true)
        ledger.abandonFocus(at: now.addingTimeInterval(600))
        XCTAssertEqual(ledger.focusMinutes(on: now), 0)
        XCTAssertTrue(ledger.life.focusSessions[0].interrupted)
        XCTAssertNil(ledger.life.activeFocus)
    }
    func testGentleDetoxUsesStricterPersonalLimit() {
        let now = Date(); var ledger = Ledger()
        ledger.life.profile.completedIntro = true
        ledger.life.detox = DetoxPlan(start: now, end: now.addingTimeInterval(600), days: 7, hard: false)
        XCTAssertEqual(ledger.dailyAvailableSeconds(at: now), 1800)
        ledger.life.profile.dailyBudget = 10
        XCTAssertEqual(ledger.dailyAvailableSeconds(at: now), 600)
    }
}

extension WellbeingTests {
    func testDifficultyOverridesLegacyRewardWithoutChangingBalance() throws {
        var ledger = Ledger(); ledger.pushUpSeconds = 15; ledger.squatSeconds = 15; ledger.balanceSeconds = 420
        for (difficulty, seconds) in [(Difficulty.gentle, 15), (.balanced, 30), (.ambitious, 60)] {
            ledger.life.profile.difficulty = difficulty
            let restored = try JSONDecoder().decode(Ledger.self, from: JSONEncoder().encode(ledger))
            XCTAssertEqual(restored.repetitionReward, seconds)
            XCTAssertEqual(restored.balanceSeconds, 420)
        }
    }
}
