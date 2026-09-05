import SwiftUI
import AVFoundation
import Vision
import ImageIO

final class PoseCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let exercise: Exercise
    private let queue = DispatchQueue(label: "unscroll.camera", qos: .userInitiated)
    private var reps = RepetitionCounter()
    private var hold = HoldCounter()
    private var lastFrame = 0.0
    private var wantsRunning = false
    @Published var amount = 0
    @Published var hint = "Kamera wird vorbereitet …"
    @Published var cameraError: String?

    init(exercise: Exercise) { self.exercise = exercise; super.init() }

    func start() {
        queue.async { self.wantsRunning = true }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.configure() } else { self.fail("Kamerazugriff wurde nicht erlaubt. Du kannst ihn in den iPhone-Einstellungen aktivieren.") }
            }
        default: fail("Für die Übungserkennung bitte Kamerazugriff in den iPhone-Einstellungen erlauben.")
        }
    }

    private func fail(_ text: String) { DispatchQueue.main.async { self.cameraError = text; self.hint = text } }

    private func configure() {
        queue.async {
            guard self.wantsRunning else { return }
            do {
                if self.session.inputs.isEmpty {
                    self.session.beginConfiguration()
                    defer { self.session.commitConfiguration() }
                    self.session.sessionPreset = .medium
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                        throw UnscrollCameraError.unavailable
                    }
                    let input = try AVCaptureDeviceInput(device: device)
                    guard self.session.canAddInput(input) else { throw UnscrollCameraError.unavailable }
                    self.session.addInput(input)
                    let output = AVCaptureVideoDataOutput()
                    output.alwaysDiscardsLateVideoFrames = true
                    output.setSampleBufferDelegate(self, queue: self.queue)
                    guard self.session.canAddOutput(output) else { throw UnscrollCameraError.unavailable }
                    self.session.addOutput(output)
                    if let connection = output.connection(with: .video) {
                        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                        connection.automaticallyAdjustsVideoMirroring = false
                        if connection.isVideoMirroringSupported { connection.isVideoMirrored = false }
                    }
                }
                self.session.startRunning()
            } catch { self.fail(error.localizedDescription) }
        }
    }

    func stop() {
        queue.async {
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            self.reps.resetTracking()
            self.hold.update(valid: false, at: ProcessInfo.processInfo.systemUptime)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard wantsRunning, now - lastFrame >= 0.08, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = now
        let request = VNDetectHumanBodyPoseRequest()
        do {
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([request])
            guard let results = request.results, results.count == 1, let observation = results.first else {
                invalid("Bitte genau eine Person vollständig im Bild.", now: now); return
            }
            let points = try observation.recognizedPoints(.all)
            let width = Double(CVPixelBufferGetWidth(pixelBuffer))
            let height = Double(CVPixelBufferGetHeight(pixelBuffer))
            func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let value = points[name], value.confidence >= 0.55 else { return nil }
                return CGPoint(x: Double(value.location.x) * width, y: Double(value.location.y) * height)
            }
            let sides: [[VNHumanBodyPoseObservation.JointName]] = [
                [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle],
                [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]
            ]
            guard let side = sides.first(where: { $0.allSatisfy { point($0) != nil } }) else {
                invalid("Schultern, Arme, Hüfte und Füße müssen sichtbar sein.", now: now); return
            }
            let p = side.compactMap(point)
            let elbow = Self.angle(p[0], p[1], p[2])
            let hip = Self.angle(p[0], p[3], p[4])
            let knee = Self.angle(p[3], p[4], p[5])
            let horizontal = abs(p[0].x - p[3].x) > abs(p[0].y - p[3].y) * 1.25
            let vertical = abs(p[0].y - p[3].y) > abs(p[0].x - p[3].x) * 0.8
            var position: RepetitionCounter.Position = .invalid
            var instruction = "Bewege dich langsam und vollständig."
            switch exercise {
            case .pushups:
                guard horizontal && hip > 150 && knee > 145 else { invalid("Seitlich aufstellen, Körper in einer Linie halten.", now: now); return }
                position = elbow > 150 ? .ready : (elbow < 100 ? .contracted : .invalid)
                instruction = elbow < 100 ? "Gut. Jetzt wieder hochdrücken." : "Arme beugen und kontrolliert absenken."
            case .squats:
                guard vertical else { invalid("Seitlich zur Kamera aufrecht stehen.", now: now); return }
                position = knee > 155 ? .ready : (knee < 105 ? .contracted : .invalid)
                instruction = knee < 105 ? "Gut. Jetzt wieder aufrichten." : "Langsam die Knie beugen."
            case .situps:
                guard knee < 135 else { invalid("Knie anwinkeln, seitlich zur Kamera positionieren.", now: now); return }
                position = hip > 115 ? .ready : (hip < 75 ? .contracted : .invalid)
                instruction = hip < 75 ? "Gut. Langsam zurücklegen." : "Oberkörper kontrolliert anheben."
            case .plank:
                let valid = horizontal && hip > 155 && knee > 150 && elbow > 65 && elbow < 115
                hold.update(valid: valid, at: now)
                publish(Int(hold.seconds), hint: valid ? "Position erkannt. Ruhig weiterhalten." : "Unterarme aufstützen und den Körper gerade halten.")
                return
            }
            // Preserve continuous tracking while the user moves between the endpoint poses.
            reps.update(position == .invalid ? .moving : position, at: now)
            publish(reps.count, hint: instruction)
        } catch { invalid("Körper gerade nicht erkennbar. Position und Licht prüfen.", now: now) }
    }

    private func invalid(_ text: String, now: Double) {
        reps.resetTracking(); hold.update(valid: false, at: now)
        publish(exercise == .plank ? Int(hold.seconds) : reps.count, hint: text)
    }

    private func publish(_ amount: Int, hint: String) {
        DispatchQueue.main.async { self.amount = amount; self.hint = hint }
    }

    private static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let ux = a.x - b.x, uy = a.y - b.y, vx = c.x - b.x, vy = c.y - b.y
        let denominator = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
        guard denominator > 0 else { return 0 }
        return Double(acos(max(-1, min(1, (ux * vx + uy * vy) / denominator))) * 180 / .pi)
    }
}

enum UnscrollCameraError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Kamera nicht verfügbar. Bitte auf einem echten iPhone testen." }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        }
    }
    func makeUIView(context: Context) -> Preview {
        let view = Preview(); view.previewLayer.session = session; view.previewLayer.videoGravity = .resizeAspect
        return view
    }
    func updateUIView(_ uiView: Preview, context: Context) {}
}

struct WorkoutView: View {
    let exercise: Exercise
    @StateObject private var camera: PoseCamera
    @EnvironmentObject var model: UnscrollModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var id = UUID()
    @State private var saved = false
    init(exercise: Exercise) { self.exercise = exercise; _camera = StateObject(wrappedValue: PoseCamera(exercise: exercise)) }
    var body: some View {
        VStack(spacing: 16) {
            HStack { Text(exercise.title).font(.title.bold()); Spacer(); Button("Abbrechen") { dismiss() } }.padding(.horizontal)
            CameraPreview(session: camera.session).clipShape(RoundedRectangle(cornerRadius: 24)).overlay(alignment: .top) {
                Text("Kameraerkennung · Beta").font(.caption.bold()).padding(8).background(.black.opacity(0.6), in: Capsule()).padding()
            }
            Text("\(camera.amount)").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
            Text(exercise.unit).foregroundStyle(.secondary)
            Text(camera.hint).multilineTextAlignment(.center).frame(minHeight: 44)
            Button("Beenden und Zeit gutschreiben") {
                camera.stop()
                model.record(exercise: exercise, amount: camera.amount, id: id)
                if model.state.journal.workouts.contains(where: { $0.id == id }) { saved = true; dismiss() }
            }.buttonStyle(.borderedProminent).disabled(camera.amount == 0 || saved)
            Text("+\(model.state.journal.reward(exercise: exercise, amount: camera.amount)) Minuten · Bilder werden nicht gespeichert.").font(.caption).foregroundStyle(.secondary)
        }.padding().background(Color.black)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: phase) { _, value in if value == .active { camera.start() } else { camera.stop() } }
    }
}
