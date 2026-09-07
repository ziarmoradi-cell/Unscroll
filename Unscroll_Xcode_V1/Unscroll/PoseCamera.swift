import AVFoundation
import Vision
import SwiftUI
import ImageIO

// Configuration and Vision are serialized. Generation tokens discard old frames.
final class PoseCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var problem: String?
    @Published var running = false
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
        session.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw NSError(domain: "Unscroll", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keine Frontkamera verfügbar."])
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
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported { connection.isVideoMirrored = false }
        }
        configured = true
    }
    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        generation = UUID(); running = false
        onFrame?(PoseFrame(time: ProcessInfo.processInfo.systemUptime, people: 0))
        queue.async { [weak self] in self?.session.stopRunning() }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFrameTime >= 1.0 / 15, let pixel = CMSampleBufferGetImageBuffer(buffer) else { return }
        lastFrameTime = now
        let token = captureGeneration
        let request = VNDetectHumanBodyPoseRequest()
        var result = PoseFrame(time: now, people: 0)
        do {
            try VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .up).perform([request])
            let observations = request.results ?? []
            result.people = observations.count
            if observations.count == 1, let observation = observations.first {
                let points = try observation.recognizedPoints(.all)
                let aspect = Double(CVPixelBufferGetWidth(pixel)) / Double(CVPixelBufferGetHeight(pixel))
                func joint(_ name: VNHumanBodyPoseObservation.JointName) -> Joint? {
                    guard let p = points[name] else { return nil }
                    return Joint(x: Double(p.location.x) * aspect, y: Double(p.location.y), confidence: Double(p.confidence))
                }
                func body(_ names: [VNHumanBodyPoseObservation.JointName]) -> BodySide? {
                    let p = names.compactMap(joint)
                    guard p.count == 6 else { return nil }
                    return BodySide(shoulder: p[0], elbow: p[1], wrist: p[2], hip: p[3], knee: p[4], ankle: p[5])
                }
                result.left = body([.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle])
                result.right = body([.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle])
            }
        } catch { result.people = 0 }
        let frame = result
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == token else { return }
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
    func makeUIView(context: Context) -> UIView {
        let view = CameraSurface(); view.preview.session = session; view.preview.videoGravity = .resizeAspect
        if let c = view.preview.connection {
            if c.isVideoOrientationSupported { c.videoOrientation = .portrait }
            if c.isVideoMirroringSupported { c.isVideoMirrored = true }
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
