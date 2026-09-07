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

extension CounterTests {
    func testFastFullRepsWithoutHoldingEndpoints() {
        for exercise in [Exercise.pushUps, .squats] {
            var counter = PoseCounter(exercise: exercise)
            let up = exercise == .pushUps ? top : standing
            let down = exercise == .pushUps ? bottom : squat
            var time = 0.0
            func frames(_ body: BodySide, _ count: Int) {
                for _ in 0..<count { time += 1.0/30; counter.process(PoseFrame(time: time, left: body)) }
            }
            frames(up, 3)
            for _ in 0..<5 {
                frames(down, 5) // Less than the old required 150 ms stable dwell.
                frames(up, 3)
            }
            XCTAssertEqual(counter.progress.reps, 5)
        }
    }
    func testSquatDoesNotNeedVisibleHands() {
        var up = standing; var down = squat
        up.wrist.confidence = 0; up.elbow.confidence = 0
        down.wrist.confidence = 0; down.elbow.confidence = 0
        var counter = PoseCounter(exercise: .squats); var time = 0.0
        feed(&counter, body: up, count: 3, time: &time)
        feed(&counter, body: down, count: 3, time: &time)
        feed(&counter, body: up, count: 3, time: &time)
        XCTAssertEqual(counter.progress.reps, 1)
    }
    func testModerateConfidenceBodyCanBeRecognized() {
        var body = top
        body.wrist.confidence = 0.35; body.ankle.confidence = 0.4
        var counter = PoseCounter(exercise: .plank); var time = 0.0
        feed(&counter, body: body, count: 11, time: &time)
        XCTAssertTrue(counter.progress.validPose)
        XCTAssertEqual(counter.progress.plankSeconds, 1, accuracy: 0.001)
    }
    func testShallowFastPushUpsNeverCount() {
        var counter = PoseCounter(exercise: .pushUps); var time = 0.0
        var shallow = top; shallow.elbow.x = 0.20
        feed(&counter, body: top, count: 3, time: &time)
        for _ in 0..<10 {
            feed(&counter, body: shallow, count: 3, time: &time)
            feed(&counter, body: top, count: 3, time: &time)
        }
        XCTAssertEqual(counter.progress.reps, 0)
    }
    func testObscuredSupportingHandStillPausesPlank() {
        var counter = PoseCounter(exercise: .plank); var time = 0.0
        feed(&counter, body: top, count: 11, time: &time)
        var hidden = top; hidden.wrist.confidence = 0
        feed(&counter, body: hidden, count: 11, time: &time)
        XCTAssertEqual(counter.progress.plankSeconds, 1, accuracy: 0.001)
        XCTAssertEqual(counter.progress.currentHold, 0)
    }
    func testOverlayMatchesAspectFitAndFrontCameraMirror() {
        let joint = Joint(x: 0.125, y: 0.75)
        let front = PreviewProjection.point(joint, aspect: 0.5, width: 300, height: 400, mirrored: true)
        let rear = PreviewProjection.point(joint, aspect: 0.5, width: 300, height: 400, mirrored: false)
        XCTAssertEqual(front.x, 200, accuracy: 0.001)
        XCTAssertEqual(rear.x, 100, accuracy: 0.001)
        XCTAssertEqual(front.y, 100, accuracy: 0.001)
        let letterbox = PreviewProjection.point(Joint(x: 0.5, y: 1), aspect: 1, width: 300, height: 500, mirrored: false)
        XCTAssertEqual(letterbox.x, 150, accuracy: 0.001)
        XCTAssertEqual(letterbox.y, 100, accuracy: 0.001)
    }
}

extension CounterTests {
    func testFastTrajectoryCountsWithOnlyOneSampleAtEachEndpoint() {
        var counter = PoseCounter(exercise: .pushUps)
        var time = 0.0
        func sample(_ degrees: Double) {
            var body = top
            let a = degrees * Double.pi / 180
            body.wrist = Joint(x: body.elbow.x + sin(a) * 0.2, y: body.elbow.y + cos(a) * 0.2)
            time += 1.0 / 30
            counter.process(PoseFrame(time: time, left: body))
        }
        sample(170); sample(170)
        for _ in 0..<5 {
            for angle in [140.0, 115, 95, 115, 140, 165] { sample(angle) }
        }
        XCTAssertEqual(counter.progress.reps, 5)
    }
}
