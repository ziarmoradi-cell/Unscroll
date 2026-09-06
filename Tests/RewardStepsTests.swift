import XCTest
@testable import UnscrollCore

final class RewardStepsTests: XCTestCase {
    func testAllModesAndPlankBoundaries() {
        for mode in Difficulty.allCases {
            var journal = Journal(); journal.profile.difficulty = mode
            for exercise in [Exercise.pushups, .squats, .situps] {
                XCTAssertEqual(journal.reward(exercise: exercise, amount: 4), 4 * mode.multiplier)
            }
            XCTAssertEqual(journal.reward(exercise: .plank, amount: 29), 0)
            XCTAssertEqual(journal.reward(exercise: .plank, amount: 30), mode.multiplier)
            XCTAssertEqual(journal.reward(exercise: .plank, amount: 65), 2 * mode.multiplier)
        }
    }
    func testStepsSurviveReloadAndCannotBeClaimedTwice() throws {
        var journal = Journal(); journal.profile.difficulty = .beginner
        let now = Date()
        journal.updateSteps(2500, at: now)
        XCTAssertEqual(journal.claimSteps(at: now), 6)
        journal = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
        journal.profile.difficulty = .hard
        XCTAssertEqual(journal.claimSteps(at: now), 0)
        journal.updateSteps(1500, at: now)
        XCTAssertEqual(journal.claimSteps(at: now), 0)
        journal.updateSteps(3000, at: now)
        XCTAssertEqual(journal.claimSteps(at: now), 1)
        XCTAssertEqual(journal.bank, 7)
        let tomorrow = journal.stepCalendar.date(byAdding: .day, value: 1, to: now)!
        journal.updateSteps(1000, at: tomorrow)
        XCTAssertEqual(journal.claimSteps(at: tomorrow), 1)
        XCTAssertEqual(journal.stepDay(at: now).minutes, 7)
    }
    func testOldJournalMigrationPreservesData() throws {
        let data = try JSONEncoder().encode(Journal())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var profile = try XCTUnwrap(json["profile"] as? [String: Any])
        profile.removeValue(forKey: "difficulty"); profile["minutesPerRep"] = 1
        json["profile"] = profile; json["bank"] = 42
        let old = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.bank, 42); XCTAssertEqual(old.profile.mode, .hard)
        XCTAssertEqual(old.stepDay().steps, 0)
    }
}
