import XCTest
@testable import UnscrollCore

final class CounterTests: XCTestCase {
    let top = BodySide(shoulder: Joint(x: 0.15, y: 0.6), elbow: Joint(x: 0.15, y: 0.4), wrist: Joint(x: 0.15, y: 0.2), hip: Joint(x: 0.4, y: 0.6), knee: Joint(x: 0.6, y: 0.6), ankle: Joint(x: 0.8, y: 0.6))
    var bottom: BodySide { var b = top; b.elbow = Joint(x: 0.3, y: 0.45); b.wrist = Joint(x: 0.15, y: 0.3); return b }
    let standing = BodySide(shoulder: Joint(x: 0.25, y: 0.9), elbow: Joint(x: 0.25, y: 0.75), wrist: Joint(x: 0.25, y: 0.65), hip: Joint(x: 0.25, y: 0.6), knee: Joint(x: 0.25, y: 0.35), ankle: Joint(x: 0.25, y: 0.1))
    var squat: BodySide { var b = standing; b.shoulder.y = 0.8; b.hip.y = 0.45; b.knee = Joint(x: 0.45, y: 0.45); b.ankle.x = 0.45; return b }
    func feed(_ counter: inout PoseCounter, body: BodySide, count: Int, time: inout Double, people: Int = 1) {
        for _ in 0..<count { time += 0.1; counter.process(PoseFrame(time: time, left: body, people: people)) }
    }
    func testPushUpsRequireWholeCycleAndCannotRepeatWhileHolding() {
        var c = PoseCounter(exercise: .pushUps); var time = 0.0
        feed(&c, body: bottom, count: 10, time: &time); XCTAssertEqual(c.progress.reps, 0)
        feed(&c, body: top, count: 5, time: &time)
        feed(&c, body: bottom, count: 5, time: &time); XCTAssertEqual(c.progress.reps, 0)
        feed(&c, body: top, count: 5, time: &time); XCTAssertEqual(c.progress.reps, 1)
        feed(&c, body: top, count: 50, time: &time); XCTAssertEqual(c.progress.reps, 1)
    }
    func testSquatsRequireFullReturnToStanding() {
        var c = PoseCounter(exercise: .squats); var time = 0.0
        feed(&c, body: standing, count: 5, time: &time)
        feed(&c, body: squat, count: 5, time: &time); XCTAssertEqual(c.progress.reps, 0)
        feed(&c, body: standing, count: 5, time: &time); XCTAssertEqual(c.progress.reps, 1)
    }
    func testStandingCannotEarnPushUpsOrPlank() {
        for exercise in [Exercise.pushUps, .plank] {
            var c = PoseCounter(exercise: exercise); var time = 0.0
            feed(&c, body: standing, count: 100, time: &time)
            XCTAssertEqual(c.progress.reps, 0); XCTAssertEqual(c.progress.plankSeconds, 0)
        }
    }
    func testPlankStopsImmediatelyAndRecordIsContinuous() {
        var c = PoseCounter(exercise: .plank); var time = 0.0
        feed(&c, body: top, count: 101, time: &time)
        XCTAssertEqual(c.progress.plankSeconds, 10, accuracy: 0.00001)
        let earned = c.progress.plankSeconds
        var invalid = top; invalid.hip.y = 0.8
        feed(&c, body: invalid, count: 10, time: &time)
        XCTAssertEqual(c.progress.plankSeconds, earned); XCTAssertEqual(c.progress.currentHold, 0)
        feed(&c, body: top, count: 51, time: &time)
        XCTAssertEqual(c.progress.plankSeconds, 15, accuracy: 0.00001)
        XCTAssertEqual(c.progress.bestHold, 10, accuracy: 0.00001)
        XCTAssertEqual(c.progress.currentHold, 5, accuracy: 0.00001)
    }
    func testMissingFramesAndBackgroundTimeNeverEarn() {
        var c = PoseCounter(exercise: .plank); var time = 0.0
        feed(&c, body: top, count: 11, time: &time)
        let before = c.progress.plankSeconds
        time += 20
        feed(&c, body: top, count: 1, time: &time)
        XCTAssertEqual(c.progress.plankSeconds, before); XCTAssertEqual(c.progress.currentHold, 0)
        c.interrupt(); time += 50
        feed(&c, body: top, count: 1, time: &time)
        XCTAssertEqual(c.progress.plankSeconds, before)
    }
    func testOcclusionOrMultiplePeopleInvalidateRepetition() {
        for multiple in [false, true] {
            var c = PoseCounter(exercise: .pushUps); var time = 0.0
            feed(&c, body: top, count: 5, time: &time)
            feed(&c, body: bottom, count: 5, time: &time)
            var weak = bottom; weak.ankle.confidence = multiple ? 1 : 0.1
            feed(&c, body: weak, count: 1, time: &time, people: multiple ? 2 : 1)
            feed(&c, body: top, count: 5, time: &time)
            XCTAssertEqual(c.progress.reps, 0)
        }
    }
    func testSingleFrameJitterDoesNotCount() {
        var c = PoseCounter(exercise: .pushUps); var time = 0.0
        feed(&c, body: top, count: 5, time: &time)
        for _ in 0..<20 {
            feed(&c, body: bottom, count: 1, time: &time)
            feed(&c, body: top, count: 1, time: &time)
        }
        XCTAssertEqual(c.progress.reps, 0)
    }
    func testMirroredGeometryStillCounts() {
        func mirror(_ body: BodySide) -> BodySide {
            func m(_ p: Joint) -> Joint { Joint(x: 1-p.x, y: p.y, confidence: p.confidence) }
            return BodySide(shoulder: m(body.shoulder), elbow: m(body.elbow), wrist: m(body.wrist), hip: m(body.hip), knee: m(body.knee), ankle: m(body.ankle))
        }
        var c = PoseCounter(exercise: .pushUps); var time = 0.0
        feed(&c, body: mirror(top), count: 5, time: &time)
        feed(&c, body: mirror(bottom), count: 5, time: &time)
        feed(&c, body: mirror(top), count: 5, time: &time)
        XCTAssertEqual(c.progress.reps, 1)
    }
}
