import AVFoundation
import Vision
import SwiftUI
import ImageIO

// Configuration and Vision are serialized. Generation tokens discard old frames.
final class PoseCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var problem: String?
    @Published var running = false
    @Published private(set) var usingFront = true
    private var position = AVCaptureDevice.Position.front
    private var poseOrientation = CGImagePropertyOrientation.up
    private var lastOrientationSearch = 0.0
    @Published var diagnostics = "Noch keine Kamerabilder verarbeitet."
    var onFrame: ((PoseFrame) -> Void)?
    private let queue = DispatchQueue(label: "unscroll.camera", qos: .userInitiated)
    private var configured = false
    private var lastFrameTime = 0.0
    private var generation = UUID() // main thread
    private var captureGeneration = UUID() // capture queue
    private var notifications: [NSObjectProtocol] = []
    override init() {
        super.init()
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            notifications.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: .main) { [weak self] _ in
                self?.stop(); self?.problem = "Kamera unterbrochen. Training pausiert – erneut starten."
            })
        }
    }
    deinit { notifications.forEach(NotificationCenter.default.removeObserver) }
    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        generation = UUID(); let token = generation; problem = nil
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart(token)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    if allowed { self.configureAndStart(token) }
                    else { self.problem = "Erlaube den Kamerazugriff in den iPhone-Einstellungen." }
                }
            }
        default: problem = "Erlaube den Kamerazugriff in den iPhone-Einstellungen."
        }
    }
    private func configureAndStart(_ token: UUID) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.configured { try self.configure() }
                self.captureGeneration = token; self.lastFrameTime = 0
                self.session.startRunning()
                let active = self.session.isRunning
                DispatchQueue.main.async {
                    guard self.generation == token else { return }
                    self.running = active
                    if !active { self.problem = "Kamera konnte nicht gestartet werden." }
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.generation == token else { return }
                    self.problem = error.localizedDescription
                }
            }
        }
    }
    private func configure() throws {
        session.beginConfiguration(); defer { session.commitConfiguration() }
        session.inputs.forEach(session.removeInput); session.outputs.forEach(session.removeOutput)
        session.sessionPreset = .hd1280x720
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw NSError(domain: "Unscroll", code: 1, userInfo: [NSLocalizedDescriptionKey: "Diese Kamera ist nicht verfügbar."])
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw StorageFailure.unavailable }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw StorageFailure.unavailable }
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported { connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false }
        }
        configured = true
    }
    func switchCamera() {
        dispatchPrecondition(condition: .onQueue(.main))
        stop(); usingFront.toggle()
        let next: AVCaptureDevice.Position = usingFront ? .front : .back
        queue.async { [weak self] in self?.position = next; self?.configured = false }
        start()
    }
    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        generation = UUID(); running = false
        onFrame?(PoseFrame(time: ProcessInfo.processInfo.systemUptime, people: 0))
        queue.async { [weak self] in self?.session.stopRunning() }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFrameTime >= 1.0 / 30, let pixel = CMSampleBufferGetImageBuffer(buffer) else { return }
        lastFrameTime = now
        let token = captureGeneration
        var result = PoseFrame(time: now, people: 0)
        do {
            func detect(_ orientation: CGImagePropertyOrientation) throws -> [VNHumanBodyPoseObservation] {
                let request = VNDetectHumanBodyPoseRequest()
                try VNImageRequestHandler(cvPixelBuffer: pixel, orientation: orientation).perform([request])
                return request.results ?? []
            }
            func score(_ observations: [VNHumanBodyPoseObservation]) -> Int {
                guard observations.count == 1, let points = try? observations[0].recognizedPoints(.all) else { return 0 }
                return points.values.filter { $0.confidence >= 0.15 }.count
            }
            var observations = try detect(poseOrientation)
            // Vision can miss prone/horizontal bodies. Try rotated analysis, then keep
            // the winning orientation; map every landmark back to the same preview.
            if observations.count < 2 && score(observations) < 8 && now-lastOrientationSearch > 0.8 {
                lastOrientationSearch = now
                var bestScore = score(observations)
                let initialOrientation = poseOrientation
                for orientation in [CGImagePropertyOrientation.up, .right, .left] where orientation != initialOrientation {
                    let candidate = try detect(orientation); let candidateScore = score(candidate)
                    if candidateScore > bestScore { observations = candidate; bestScore = candidateScore; poseOrientation = orientation }
                }
            }
            result.people = observations.count
            if observations.count == 1, let observation = observations.first {
                let points = try observation.recognizedPoints(.all)
                let aspect = Double(CVPixelBufferGetWidth(pixel)) / Double(CVPixelBufferGetHeight(pixel))
                result.aspectRatio = aspect
                func joint(_ name: VNHumanBodyPoseObservation.JointName) -> Joint? {
                    guard let p = points[name] else { return nil }
                    let u = Double(p.location.x), v = Double(p.location.y)
                    return PreviewProjection.originalJoint(u: u, v: v, orientation: self.poseOrientation.rawValue, aspect: aspect, confidence: Double(p.confidence))
                }
                func body(_ names: [VNHumanBodyPoseObservation.JointName]) -> BodySide? {
                    // Missing hands must not hide otherwise usable squat joints or the overlay.
                    let p = names.map { joint($0) ?? Joint(x: 0, y: 0, confidence: 0) }
                    return BodySide(shoulder: p[0], elbow: p[1], wrist: p[2], hip: p[3], knee: p[4], ankle: p[5])
                }
                result.left = body([.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle])
                result.right = body([.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle])
            }
        } catch { result.people = 0 }
        let frame = result
        let elapsed = ProcessInfo.processInfo.systemUptime - now
        let points = [frame.left, frame.right].compactMap { $0 }.flatMap { [$0.shoulder,$0.elbow,$0.wrist,$0.hip,$0.knee,$0.ankle] }
        let diagnostic = "Vision: \(frame.people) Person(en) · \(points.filter { $0.confidence >= 0.15 }.count)/12 Körperpunkte · \(Int(elapsed * 1000)) ms Verarbeitung · Bildausrichtung \(poseOrientation.rawValue)"
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == token else { return }
            self.diagnostics = diagnostic
            guard ProcessInfo.processInfo.systemUptime - frame.time < 0.3 else {
                self.onFrame?(PoseFrame(time: ProcessInfo.processInfo.systemUptime, people: 0)); return
            }
            self.onFrame?(frame)
        }
    }
}

private final class CameraSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrored = true
    func makeUIView(context: Context) -> UIView {
        let view = CameraSurface(); view.preview.session = session; view.preview.videoGravity = .resizeAspect
        configure(view)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? CameraSurface { configure(view) }
    }
    private func configure(_ view: CameraSurface) {
        if let c = view.preview.connection {
            if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
            if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = mirrored }
        }
    }
}
