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
    private let watchdog = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    init(exercise: Exercise) { self.exercise = exercise; _counter = State(initialValue: PoseCounter(exercise: exercise)) }
    private var progress: WorkoutProgress { counter.progress }
    private var recordValue: Double { exercise == .plank ? progress.bestHold : Double(progress.reps) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CameraPreview(session: camera.session)
                        .frame(height: 300).background(.black).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(alignment: .topLeading) {
                            Label(progress.validPose ? "Haltung erkannt" : "Erkennung pausiert", systemImage: progress.validPose ? "checkmark.circle.fill" : "pause.circle")
                                .font(.caption.bold()).padding(10).background(.ultraThinMaterial, in: Capsule()).padding(12)
                        }
                    Text(exercise == .plank ? "\(Int(progress.plankSeconds)) s" : "\(progress.reps)")
                        .font(.system(size: 64, weight: .black, design: .rounded)).monospacedDigit()
                    Text(camera.problem ?? progress.message).multilineTextAlignment(.center)
                    if exercise == .plank {
                        Text("Aktuelle Haltung: \(Int(progress.currentHold)) s · 10 s = 1 Minute")
                        ProgressView(value: progress.plankSeconds.truncatingRemainder(dividingBy: 10), total: 10)
                    } else { Text("Pro Wiederholung: \(reward) Sekunden Social Media") }
                    Label("PR: \(Int(max(baseline, recordValue))) \(exercise == .plank ? "Sekunden am Stück" : "Wiederholungen")", systemImage: "trophy.fill").foregroundStyle(.mint)
                    if celebrated { Text("Neuer persönlicher Rekord! 🎉").font(.headline).foregroundStyle(.mint) }
                    Text("Handy aufrecht und stabil aufstellen. Trainiere seitlich zur Frontkamera, mit ganzem Körper im Bild. Kamera bleibt auf deinem iPhone.").font(.footnote).foregroundStyle(.secondary)
                    if !camera.running {
                        Button(started ? "Kamera erneut starten" : "Training starten") { start() }.buttonStyle(.borderedProminent)
                        if camera.problem != nil {
                            Button("iPhone-Einstellungen öffnen") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                        }
                    }
                    Button("Training beenden") { finish(); dismiss() }.buttonStyle(.bordered)
                }.padding()
            }.navigationTitle(exercise.title)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { finish(); dismiss() } } }
        }
        .interactiveDismissDisabled(camera.running)
        .onAppear {
            baseline = store.ledger.record(exercise)
            reward = exercise == .pushUps ? store.ledger.pushUpSeconds : store.ledger.squatSeconds
            camera.onFrame = receive
        }
        .onDisappear { finish(); camera.onFrame = nil }
        .onChange(of: camera.running) { _, running in UIApplication.shared.isIdleTimerDisabled = running }
        .onChange(of: scenePhase) { _, phase in if phase != .active { finish() } }
        .onReceive(watchdog) { _ in
            if camera.running && ProcessInfo.processInfo.systemUptime - lastReceived > 0.35 { counter.interrupt() }
        }
    }
    private func start() { started = true; counter.interrupt(); camera.start() }
    private func receive(_ frame: PoseFrame) {
        lastReceived = ProcessInfo.processInfo.systemUptime; counter.process(frame)
        let checkpoint = exercise == .plank ? Int(progress.plankSeconds) : progress.reps
        if checkpoint != lastSaved { save(); lastSaved = checkpoint }
        if !celebrated && recordValue >= max(1, floor(baseline) + 1) {
            celebrated = true; UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    private func save() { store.checkpoint(id: id, exercise: exercise, progress: progress, reward: reward) }
    private func finish() { save(); camera.stop(); counter.interrupt(); UIApplication.shared.isIdleTimerDisabled = false }
}
