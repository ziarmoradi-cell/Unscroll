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
    var aspectRatio: Double = 1
}

struct WorkoutProgress {
    var reps = 0
    var plankSeconds: Double = 0
    var currentHold: Double = 0
    var bestHold: Double = 0
    var validPose = false
    var depth: Double = 0
    var bodyDetected = false
    var message = "Stelle dich seitlich zur Kamera. Dein ganzer Körper muss sichtbar sein."
}

struct PoseCounter {
    let exercise: Exercise
    init(exercise: Exercise) { self.exercise = exercise }
    private(set) var progress = WorkoutProgress()
    private var lastTime: Double?
    private var phase = 0 // 0: needs start, 1: top armed, 2: bottom reached
    private var endpointFrames = 0
    private var cycleStart: Double?
    private var side: Int?
    private var previousValid = false
    private var lastHip: Joint?
    private var lastMovementAngle: Double?

    static func angle(_ a: Joint, _ b: Joint, _ c: Joint) -> Double {
        let denominator = a.distance(to: b) * c.distance(to: b)
        guard denominator > 0.0001 else { return 0 }
        let dot = ((a.x-b.x)*(c.x-b.x) + (a.y-b.y)*(c.y-b.y)) / denominator
        return acos(max(-1, min(1, dot))) * 180 / .pi
    }

    mutating func interrupt() {
        phase = 0; endpointFrames = 0; cycleStart = nil; side = nil
        previousValid = false; lastTime = nil; lastHip = nil; lastMovementAngle = nil
        progress.currentHold = 0; progress.validPose = false; progress.depth = 0; progress.bodyDetected = false
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
        func required(_ body: BodySide) -> [(String, Joint)] {
            if exercise == .pushUps { return [("Schulter", body.shoulder), ("Hüfte", body.hip), ("Ellbogen", body.elbow), ("Hände", body.wrist)] }
            if exercise == .plank {
                let support = body.elbow.confidence > body.wrist.confidence ? ("Ellbogen", body.elbow) : ("Hände", body.wrist)
                return [("Schulter", body.shoulder), ("Hüfte", body.hip), ("Füße", body.ankle), support]
            }
            return [("Schulter", body.shoulder), ("Hüfte", body.hip), ("Knie", body.knee), ("Füße", body.ankle)]
        }
        func quality(_ body: BodySide?) -> Double {
            guard let body else { return 0 }
            return required(body).map { $0.1.confidence }.min() ?? 0
        }
        let best = quality(frame.left) >= quality(frame.right) ? 0 : 1
        if side == nil { side = best }
        // Never join endpoints from different body sides in the same repetition.
        if let current = side, quality(candidates[current]) < 0.15, quality(candidates[best]) >= 0.15 {
            interrupt(); side = best; lastTime = frame.time
        }
        guard let index = side, let body = candidates[index] else {
            interrupt(); progress.message = "Noch keine Körperpunkte – tritt ins Kamerabild und sorge für Licht."
            return progress
        }
        let joints = required(body)
        let missing = joints.filter { !$0.1.confidence.isFinite || $0.1.confidence < 0.15 || !$0.1.x.isFinite || !$0.1.y.isFinite }
        guard missing.isEmpty else {
            interrupt(); progress.message = "Noch nicht gut sichtbar: " + missing.map { $0.0 }.joined(separator: ", ") + ". Handy seitlich aufstellen."
            return progress
        }
        guard body.shoulder.distance(to: body.hip) > 0.025, (exercise == .pushUps || body.hip.distance(to: body.ankle) > 0.05) else {
            interrupt(); progress.message = "Etwas näher zur Kamera – dein Körper ist noch sehr klein im Bild."
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
        let horizontal = abs(body.shoulder.y - body.ankle.y) < abs(body.shoulder.x - body.ankle.x) * 0.8
        let straight = hipAngle >= 145 && kneeAngle >= 150
        let armSupport = body.wrist.y < body.shoulder.y - 0.015
        let valid: Bool
        let top: Bool
        let bottom: Bool
        switch exercise {
        case .pushUps:
            valid = armSupport && abs(body.shoulder.y-body.hip.y) < abs(body.shoulder.x-body.hip.x) * 1.2
            top = elbowAngle >= 150
            bottom = elbowAngle <= 100
        case .squats:
            valid = body.shoulder.y > body.hip.y && body.hip.y > body.ankle.y &&
                body.shoulder.y - body.hip.y > abs(body.shoulder.x - body.hip.x) * 0.2
            top = kneeAngle >= 155 && hipAngle >= 145
            bottom = kneeAngle < 110 && body.hip.y - body.knee.y < body.hip.distance(to: body.knee) * 0.45
        case .plank:
            let aligned = Self.angle(body.shoulder, body.hip, body.ankle) >= 140
            let supported = (body.wrist.confidence >= 0.15 && body.wrist.y < body.shoulder.y) ||
                (body.elbow.confidence >= 0.15 && body.elbow.y < body.shoulder.y)
            valid = horizontal && aligned && supported
            top = false; bottom = false
        }
        guard valid else {
            interrupt()
            progress.bodyDetected = true
            if exercise == .squats { progress.message = "Körper gefunden. Stelle die Kamera seitlich auf Hüfthöhe auf." }
            else if !horizontal { progress.message = "Körper gefunden. Geh in die Stützposition; die Kamera schaut seitlich auf dich." }
            else if !straight { progress.message = "Körper gefunden. Hüfte und Beine möglichst in einer Linie halten." }
            else { progress.message = "Körper gefunden. Hände bzw. Unterarme unter den Oberkörper setzen." }
            return progress
        }
        progress.validPose = true; progress.bodyDetected = true
        progress.depth = exercise == .pushUps ? max(0, min(1, (150-elbowAngle)/50)) : max(0, min(1, (155-kneeAngle)/45))
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
        if let cycleStart, frame.time - cycleStart > 12 { phase = 0; endpointFrames = 0; self.cycleStart = nil }
        let condition = phase == 1 ? bottom : top
        let movementAngle = exercise == .pushUps ? elbowAngle : kneeAngle
        let previousAngle = lastMovementAngle
        lastMovementAngle = movementAngle
        // A single endpoint sample is enough when an adjacent intermediate angle
        // confirms the trajectory. A direct top/bottom spike still needs two samples.
        let approachingBottom = phase == 1 && bottom && previousAngle.map {
            $0 > movementAngle && $0 < 145 && $0 - movementAngle <= 45
        } == true
        let approachingTop = phase == 2 && top && previousAngle.map {
            $0 < movementAngle && $0 > 120 && movementAngle - $0 <= 45
        } == true
        endpointFrames = condition ? endpointFrames + 1 : 0
        if endpointFrames >= 2 || approachingBottom || approachingTop {
            if phase == 0 { phase = 1; cycleStart = frame.time }
            else if phase == 1 { phase = 2 }
            else {
                if frame.time - (cycleStart ?? frame.time) >= 0.18 { progress.reps += 1 }
                phase = 1; cycleStart = frame.time
            }
            endpointFrames = 0
        }
        progress.message = phase == 0 ? "Einmal ganz nach oben – dann kann es losgehen." : phase == 1 ? "Tief runter – dein Tempo bestimmst du." : "Tiefe erreicht. Wieder ganz hoch!"
        return progress
    }
}
