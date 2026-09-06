import Foundation

enum Exercise: String, Codable, CaseIterable, Identifiable {
    case pushUps, squats, plank
    var id: String { rawValue }
    var title: String {
        switch self { case .pushUps: return "Liegestütze"; case .squats: return "Kniebeugen"; case .plank: return "Plank" }
    }
    var symbol: String {
        switch self { case .pushUps: return "figure.strengthtraining.functional"; case .squats: return "figure.strengthtraining.traditional"; case .plank: return "figure.core.training" }
    }
}

// Coordinates are upright, unmirrored, y-up and measured in image-height units.
// Scaling x by image aspect ratio is essential for correct joint angles.
struct Joint {
    var x: Double
    var y: Double
    var confidence: Double = 1
    func distance(to b: Joint) -> Double { hypot(x - b.x, y - b.y) }
}

struct BodySide {
    var shoulder: Joint
    var elbow: Joint
    var wrist: Joint
    var hip: Joint
    var knee: Joint
    var ankle: Joint
    var confidence: Double { [shoulder, elbow, wrist, hip, knee, ankle].map(\.confidence).min() ?? 0 }
}

struct PoseFrame {
    var time: TimeInterval
    var left: BodySide?
    var right: BodySide?
    var people: Int = 1
}

struct WorkoutProgress {
    var reps = 0
    var plankSeconds: Double = 0
    var currentHold: Double = 0
    var bestHold: Double = 0
    var validPose = false
    var message = "Stelle dich seitlich zur Kamera. Dein ganzer Körper muss sichtbar sein."
}

struct PoseCounter {
    let exercise: Exercise
    init(exercise: Exercise) { self.exercise = exercise }
    private(set) var progress = WorkoutProgress()
    private var lastTime: Double?
    private var phase = 0 // 0: needs start, 1: top armed, 2: bottom reached
    private var phaseSince: Double?
    private var cycleStart: Double?
    private var side: Int?
    private var previousValid = false
    private var lastHip: Joint?

    static func angle(_ a: Joint, _ b: Joint, _ c: Joint) -> Double {
        let denominator = a.distance(to: b) * c.distance(to: b)
        guard denominator > 0.0001 else { return 0 }
        let dot = ((a.x-b.x)*(c.x-b.x) + (a.y-b.y)*(c.y-b.y)) / denominator
        return acos(max(-1, min(1, dot))) * 180 / .pi
    }

    mutating func interrupt() {
        phase = 0; phaseSince = nil; cycleStart = nil; side = nil
        previousValid = false; lastTime = nil; lastHip = nil
        progress.currentHold = 0; progress.validPose = false
        progress.message = "Pausiert – bring deinen ganzen Körper ins Bild."
    }

    @discardableResult mutating func process(_ frame: PoseFrame) -> WorkoutProgress {
        guard frame.time.isFinite else { interrupt(); return progress }
        let dt = lastTime.map { frame.time - $0 } ?? 0
        if dt < 0 || dt > 0.3 { interrupt() }
        lastTime = frame.time
        guard frame.people == 1 else {
            interrupt(); progress.message = frame.people > 1 ? "Bitte nur eine Person im Bild." : "Kein Körper erkannt."
            return progress
        }
        let candidates = [frame.left, frame.right]
        if side == nil {
            side = (frame.left?.confidence ?? 0) >= (frame.right?.confidence ?? 0) ? 0 : 1
        }
        guard let index = side, let body = candidates[index], body.confidence >= 0.6,
              [body.shoulder, body.elbow, body.wrist, body.hip, body.knee, body.ankle].allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              body.shoulder.distance(to: body.hip) > 0.08,
              body.hip.distance(to: body.ankle) > 0.12 else {
            interrupt(); progress.message = "Körper nicht vollständig sichtbar – etwas weiter zurück."
            return progress
        }
        if let lastHip, lastHip.distance(to: body.hip) > 0.18 {
            interrupt(); progress.message = "Kamera ruhig halten."
            return progress
        }
        lastHip = body.hip
        let hipAngle = Self.angle(body.shoulder, body.hip, body.knee)
        let kneeAngle = Self.angle(body.hip, body.knee, body.ankle)
        let elbowAngle = Self.angle(body.shoulder, body.elbow, body.wrist)
        let horizontal = abs(body.shoulder.y - body.ankle.y) < abs(body.shoulder.x - body.ankle.x) * 0.4
        let straight = hipAngle >= 155 && kneeAngle >= 155
        let armSupport = body.elbow.y < body.shoulder.y && body.wrist.y < body.shoulder.y
        let valid: Bool
        let top: Bool
        let bottom: Bool
        switch exercise {
        case .pushUps:
            valid = horizontal && straight && armSupport
            top = elbowAngle > 150
            bottom = elbowAngle < 100
        case .squats:
            valid = body.shoulder.y > body.hip.y && body.hip.y > body.ankle.y &&
                body.shoulder.y - body.hip.y > abs(body.shoulder.x - body.hip.x) * 0.65
            top = kneeAngle > 160 && hipAngle > 150
            bottom = kneeAngle < 110 && body.hip.y - body.knee.y < body.hip.distance(to: body.knee) * 0.45
        case .plank:
            let supportedElbow = abs(body.elbow.x - body.shoulder.x) < body.shoulder.distance(to: body.hip) * 0.45
            let forearm = elbowAngle >= 65 && elbowAngle <= 120 && abs(body.wrist.y - body.elbow.y) < 0.10
            valid = horizontal && straight && armSupport && supportedElbow && (forearm || elbowAngle > 150)
            top = false; bottom = false
        }
        guard valid else {
            interrupt()
            progress.message = exercise == .squats ? "Seitlich stehen, Füße und Oberkörper im Bild." : "Körper gerade halten, seitlich zur Kamera."
            return progress
        }
        progress.validPose = true
        if exercise == .plank {
            // Credit only intervals bounded by TWO valid frames. Never bridge a lost frame,
            // app suspension or invalid posture. No timer runs independently of the camera.
            if previousValid && dt > 0 && dt <= 0.3 {
                progress.plankSeconds += dt
                progress.currentHold += dt
                progress.bestHold = max(progress.bestHold, progress.currentHold)
            }
            previousValid = true
            progress.message = "Haltung erkannt – Zeit läuft."
            return progress
        }
        if let cycleStart, frame.time - cycleStart > 12 { phase = 0; phaseSince = nil; self.cycleStart = nil }
        let condition = phase == 1 ? bottom : top
        if condition {
            if phaseSince == nil { phaseSince = frame.time }
            if frame.time - (phaseSince ?? frame.time) >= 0.15 {
                if phase == 0 { phase = 1; cycleStart = frame.time }
                else if phase == 1 { phase = 2 }
                else {
                    if frame.time - (cycleStart ?? frame.time) >= 0.8 { progress.reps += 1 }
                    phase = 1; cycleStart = frame.time
                }
                phaseSince = nil
            }
        } else { phaseSince = nil }
        progress.message = phase == 0 ? "Startposition halten." : phase == 1 ? "Kontrolliert absenken." : "Wieder vollständig hoch."
        return progress
    }
}
