import SwiftUI

struct WorkoutView: View {
    let exercise: Exercise
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = PoseCamera()
    @State private var counter: PoseCounter
    @State private var id = UUID()
    @State private var baseline = 0.0
    @State private var reward = 30
    @State private var lastSaved = -1
    @State private var celebrated = false
    @State private var started = false
    @State private var lastReceived = 0.0
    @State private var poseFrame: PoseFrame?
    @State private var showLines = true
    private let watchdog = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    init(exercise: Exercise) { self.exercise = exercise; _counter = State(initialValue: PoseCounter(exercise: exercise)) }
    private var progress: WorkoutProgress { counter.progress }
    private var recordValue: Double { exercise == .plank ? progress.bestHold : Double(progress.reps) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack(alignment: .bottom) {
                        CameraPreview(session: camera.session, mirrored: camera.usingFront)
                        if showLines { SkeletonOverlay(frame: poseFrame, valid: progress.validPose, mirrored: camera.usingFront) }
                        if !camera.running {
                            VStack(spacing: 14) {
                                Image(systemName: "camera.fill").font(.largeTitle)
                                Text(camera.problem ?? "Kamera wird gestartet …").multilineTextAlignment(.center)
                                Button("Kamera starten") { start() }.buttonStyle(.borderedProminent)
                            }.padding(24).foregroundStyle(.white).frame(maxHeight: .infinity)
                        }
                        VStack(spacing: 4) {
                            Text(exercise == .plank ? "\(Int(progress.plankSeconds)) s" : "\(progress.reps)")
                                .font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
                            Text(exercise == .plank ? "erkannte Haltezeit" : "Wiederholungen").font(.caption.bold())
                        }.foregroundStyle(.white).padding(14).frame(maxWidth: .infinity).background(.black.opacity(0.5))
                    }
                    .frame(height: min(500, UIScreen.main.bounds.height * 0.53))
                    .background(.black).clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(alignment: .topLeading) {
                        Label(progress.validPose ? "Bereit · Körper erkannt" : progress.bodyDetected ? "Körper gefunden · Haltung anpassen" : "Körper suchen …", systemImage: progress.validPose ? "checkmark.circle.fill" : "viewfinder")
                            .font(.caption.bold()).padding(10).foregroundStyle(.white).background(.black.opacity(0.65), in: Capsule()).padding(10)
                    }
                    HStack {
                        Toggle("Körperlinien", isOn: $showLines).font(.subheadline)
                        Spacer(minLength: 20)
                        Button { counter.interrupt(); poseFrame = nil; camera.switchCamera() } label: { Label("Kamera", systemImage: "arrow.triangle.2.circlepath.camera") }.buttonStyle(.bordered)
                    }
                    Text("Grün: Haltung passt · Orange: erkannte Körperteile").font(.caption).foregroundStyle(.secondary)
                    Text(camera.problem ?? progress.message).multilineTextAlignment(.center)
                    if exercise == .plank {
                        Text("Aktuelle Haltung: \(Int(progress.currentHold)) s · 10 s = 1 Minute")
                        ProgressView(value: progress.plankSeconds.truncatingRemainder(dividingBy: 10), total: 10)
                    } else {
                        ProgressView("Bewegungstiefe", value: progress.depth)
                        Text("Tief runter und ganz hoch – auch schnell.").font(.subheadline.bold())
                        Text("Belohnung: +\(reward) Sekunden Social-Media-Guthaben pro gezählter Wiederholung. Keine vorgegebene Wiederholungsdauer.").font(.caption).foregroundStyle(.secondary)
                    }
                    Label("PR: \(Int(max(baseline, recordValue))) \(exercise == .plank ? "Sekunden am Stück" : "Wiederholungen")", systemImage: "trophy.fill").foregroundStyle(Palette.teal)
                    if celebrated { Text("Neuer persönlicher Rekord! 🎉").font(.headline).foregroundStyle(Palette.teal) }
                    Text(exercise == .squats ? "Handy seitlich etwa auf Hüfthöhe aufstellen. Kopf bis Füße ins Bild bringen; die Hände dürfen verdeckt sein. Gehe mit der Hüfte etwa bis auf Kniehöhe und richte dich wieder auf." : "Handy seitlich und niedrig aufstellen, leicht zu dir neigen. Schultern, Hände, Hüfte und Füße im Bild halten. Bei wenig Platz etwas weiter weg oder die Rückkamera ausprobieren.").font(.footnote).foregroundStyle(.secondary)
                    if !camera.running {
                        Button(started ? "Kamera erneut starten" : "Training starten") { start() }.buttonStyle(.borderedProminent)
                        if camera.problem != nil {
                            Button("iPhone-Einstellungen öffnen") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                        }
                    }
                    Button("Training beenden") { finish(); dismiss() }.buttonStyle(.bordered)
                }.padding()
            }.page().navigationTitle(exercise.title)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { finish(); dismiss() } } }
        }
        .interactiveDismissDisabled(camera.running)
        .onAppear {
            baseline = store.ledger.record(exercise)
            reward = exercise == .pushUps ? store.ledger.pushUpSeconds : store.ledger.squatSeconds
            camera.onFrame = receive
            #if DEBUG && targetEnvironment(simulator)
            if !ProcessInfo.processInfo.arguments.contains("--ui-testing") { start() }
            #else
            start()
            #endif
        }
        .onDisappear { finish(); camera.onFrame = nil }
        .onChange(of: camera.running) { _, running in UIApplication.shared.isIdleTimerDisabled = running }
        .onChange(of: scenePhase) { _, phase in if phase != .active { finish() } }
        .onReceive(watchdog) { _ in
            if camera.running && ProcessInfo.processInfo.systemUptime - lastReceived > 0.35 { counter.interrupt(); poseFrame = nil }
        }
    }
    private func start() { started = true; counter.interrupt(); camera.start() }
    private func receive(_ frame: PoseFrame) {
        lastReceived = ProcessInfo.processInfo.systemUptime; poseFrame = frame; counter.process(frame)
        let checkpoint = exercise == .plank ? Int(progress.plankSeconds) : progress.reps
        if checkpoint != lastSaved { save(); lastSaved = checkpoint }
        if !celebrated && recordValue >= max(1, floor(baseline) + 1) {
            celebrated = true; UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    private func save() { store.checkpoint(id: id, exercise: exercise, progress: progress, reward: reward) }
    private func finish() { save(); camera.stop(); counter.interrupt(); UIApplication.shared.isIdleTimerDisabled = false }
}
