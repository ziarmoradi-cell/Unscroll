import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var screenTime = ScreenTimeController()
    @StateObject private var steps = StepTracker()
    @StateObject private var sound = SoundPlayer()
    @State private var tab = 0
    @State private var workout: Exercise?
    @State private var picker = false
    @State private var minutes = 5
    @State private var confirmBlock = false
    @State private var day = Ledger.dayKey()
    private let tick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    var body: some View {
        Group {
            if !store.ledger.life.profile.completedIntro { IntroView() }
            else {
                TabView(selection: $tab) {
                    NavigationStack { home }.tabItem { Label("Heute", systemImage: "sun.max") }.tag(0)
                    NavigationStack { movement }.tabItem { Label("Bewegen", systemImage: "figure.walk") }.tag(1)
                    NavigationStack { FocusView() }.tabItem { Label("Fokus", systemImage: "scope") }.tag(2)
                    NavigationStack { SleepView() }.tabItem { Label("Abend", systemImage: "moon.stars") }.tag(3)
                    NavigationStack { JourneyView() }.tabItem { Label("Dein Weg", systemImage: "leaf") }.tag(4)
                }
            }
        }
        .environmentObject(screenTime).environmentObject(steps).environmentObject(sound)
        .tint(Palette.teal).preferredColorScheme(.light)
        .sheet(item: $workout, onDismiss: { store.reload() }) { WorkoutView(exercise: $0).environmentObject(store) }
        .familyActivityPicker(isPresented: $picker, selection: $screenTime.selection)
        .onChange(of: picker) { old, new in if old && !new { screenTime.saveSelection() } }
        .onChange(of: steps.snapshot) { _, value in if let value { store.claimSteps(value) } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .onReceive(tick) { _ in store.settle(); if day != Ledger.dayKey() { day = Ledger.dayKey(); steps.refresh() } }
        .onAppear {
            refresh()
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--ui-screen=workout") { tab = 1; workout = .pushUps }
            let names = ["home", "move", "focus", "sleep", "more"]
            if let index = names.firstIndex(where: { ProcessInfo.processInfo.arguments.contains("--ui-screen=\($0)") }) { tab = index }
            #endif
        }
        .alert("Hinweis", isPresented: Binding(get: { store.error != nil || screenTime.error != nil || sound.error != nil }, set: { if !$0 { store.error = nil; screenTime.error = nil; sound.error = nil } })) {
            Button("OK") { store.error = nil; screenTime.error = nil; sound.error = nil }
        } message: { Text(store.error ?? screenTime.error ?? sound.error ?? "") }
        .confirmationDialog("Jetzt sperren? Das restliche eingelöste Budget verfällt.", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Apps sperren", role: .destructive) { screenTime.blockNow(); store.reload() }
        }
    }
    private func refresh() { store.reload(); store.settle(); screenTime.refresh(); steps.refresh() }
    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Text("unscroll").font(.title2.bold()); Spacer(); Image(systemName: "leaf.fill").foregroundStyle(Palette.teal) }
                PageHeading(eyebrow: Date().formatted(.dateTime.weekday(.wide).day().month()), title: "Mehr im Moment,\n\(store.ledger.life.profile.name).", subtitle: "Dein nächster guter Moment beginnt außerhalb des Feeds.")
                VStack(alignment: .leading, spacing: 18) {
                    Label("DEINE VERDIENTE ZEIT", systemImage: "sparkles").font(.caption.weight(.bold)).tracking(2)
                    HStack(alignment: .firstTextBaseline, spacing: 8) { Text("\(store.ledger.balanceSeconds / 60)").font(.system(size: 68, weight: .medium, design: .rounded)); Text("Minuten").font(.title3); Spacer(); Image(systemName: "sun.max").font(.system(size: 44, weight: .ultraLight)) }
                    Text("+ \(store.ledger.balanceSeconds % 60) Sekunden · bewusst verdient") .font(.caption)
                    Button { tab = 1 } label: { HStack { Text("Zeit durch Bewegung verdienen"); Spacer(); Image(systemName: "arrow.up.right") }.font(.subheadline.bold()).padding(15).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain)
                }.padding(24).foregroundStyle(.white).background(Palette.teal, in: RoundedRectangle(cornerRadius: 28))
                HStack(spacing: 12) {
                    Metric(value: "\(store.ledger.life.stepTotals[Ledger.dayKey()] ?? 0)", title: "Schritte heute", symbol: "figure.walk")
                    Metric(value: "\(store.ledger.focusMinutes()) min", title: "Fokus heute", symbol: "scope")
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Dein Tagesziel").font(.headline)
                    let reps = store.ledger.workouts.filter { Ledger.dayKey($0.date) == Ledger.dayKey() }.reduce(0) { $0 + $1.reps }
                    let goal = store.ledger.life.profile.difficulty.repGoal
                    HStack { Text("\(reps) / \(goal) Wiederholungen"); Spacer(); Image(systemName: reps >= goal ? "checkmark.circle.fill" : "figure.strengthtraining.traditional").foregroundStyle(Palette.teal) }
                    ProgressView(value: Double(min(reps, goal)), total: Double(goal))
                    Text(store.ledger.life.profile.goal.rawValue + " · " + store.ledger.life.profile.difficulty.rawValue).font(.caption).foregroundStyle(.secondary)
                }.panel()
                socialCard
                VStack(alignment: .leading, spacing: 12) {
                    Label("Dein kleiner Impuls", systemImage: "lightbulb").font(.headline)
                    Text("Bevor du eine App öffnest: Was möchtest du dort gerade wirklich tun?").font(.system(size: 22, weight: .medium, design: .serif))
                    Button("Eine Fokus-Session starten") { tab = 2 }
                }.panel()
            }.padding(22)
        }.page().toolbar(.hidden, for: .navigationBar)
    }
    private var socialCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Deine digitale Grenze", systemImage: "lock.shield").font(.title3.bold())
            if !screenTime.approved {
                Text("Wähle, welche Apps du mit verdienter Zeit öffnen möchtest.").font(.subheadline).foregroundStyle(.secondary)
                Button("Bildschirmzeit verbinden") { Task { await screenTime.authorize() } }.buttonStyle(PrimaryButton())
            } else {
                Button("Apps auswählen") { picker = true }.disabled(screenTime.grant != nil || store.ledger.restricted())
                if let grant = screenTime.grant {
                    Text("\(grant.seconds / 60) Minuten Nutzungsbudget aktiv")
                    Text("Die Nutzung deiner gewählten Apps zählt, bis das Budget verbraucht ist. Spätestens nach 24 Stunden endet die Freigabe.").font(.caption).foregroundStyle(.secondary)
                    Button("Jetzt wieder sperren") { confirmBlock = true }
                } else if store.ledger.restricted() {
                    Label("Fokus, Nacht oder Detox ist aktiv", systemImage: "lock.fill")
                    Text("Dein Guthaben bleibt erhalten. Freischalten ist nach dieser Pause wieder möglich.").font(.caption)
                } else {
                    Text("Heute noch bis zu \(store.ledger.dailyAvailableSeconds() / 60) Minuten einlösbar").font(.subheadline)
                    Stepper("\(minutes) Minuten", value: $minutes, in: 1...120)
                    Button("Zeit bewusst einlösen") { screenTime.unlock(minutes: minutes); store.reload() }.buttonStyle(PrimaryButton())
                        .disabled(!screenTime.hasSelection || min(store.ledger.balanceSeconds, store.ledger.dailyAvailableSeconds()) < minutes * 60)
                    Text("Das Budget wird direkt abgezogen. Vorzeitig beendete Freigaben werden nicht erstattet.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.panel()
    }
    private var movement: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(eyebrow: "Bewegen statt scrollen", title: "Ein guter Tausch.", subtitle: "Kamera an. Bewegung rein. Zeit verdient.")
                ForEach(Exercise.allCases) { exercise in
                    Button { workout = exercise } label: {
                        HStack(spacing: 16) {
                            Image(systemName: exercise.symbol).font(.title).foregroundStyle(Palette.teal).frame(width: 40)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(exercise.title).font(.title3.bold())
                                Text(exercise == .plank ? "10 Sekunden = 1 Minute" : "Guthaben pro Wiederholung: +\(exercise == .pushUps ? store.ledger.pushUpSeconds : store.ledger.squatSeconds) Sekunden").font(.caption).foregroundStyle(.secondary)
                                Label("PR \(Int(store.ledger.record(exercise))) \(exercise == .plank ? "s am Stück" : "Wdh.")", systemImage: "trophy").font(.caption.bold()).foregroundStyle(Palette.teal)
                            }; Spacer(); Image(systemName: "arrow.up.right")
                        }.panel()
                    }.buttonStyle(.plain)
                }
                StepsCard()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Damit jede Bewegung zählt").font(.headline)
                    Text("Stelle dein Handy aufrecht und stabil auf. Trainiere seitlich zur Kamera, mit deinem ganzen Körper und den Füßen im Bild. Sorge für Licht und Platz.")
                    Text("Plank zählt nur in erkannter Haltung. Bei einer Pause stoppt die Zeit; dein Rekord misst die längste Haltung am Stück.")
                    Text("Bilder werden auf deinem iPhone verarbeitet und nicht gespeichert.").font(.caption).foregroundStyle(.secondary)
                }.panel()
            }.padding(22)
        }.page().toolbar(.hidden, for: .navigationBar)
    }
}
struct StepsCard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var steps: StepTracker
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Jeder Weg zählt", systemImage: "figure.walk").font(.title3.bold())
            let total = store.ledger.life.stepTotals[Ledger.dayKey()] ?? 0
            Text("\(total) / \(store.ledger.life.profile.difficulty.stepGoal) Schritte").font(.headline)
            ProgressView(value: Double(min(total, store.ledger.life.profile.difficulty.stepGoal)), total: Double(store.ledger.life.profile.difficulty.stepGoal))
            Text("1.000 Schritte = 1 Minute · bis zu 10 Minuten täglich").font(.subheadline)
            Text(steps.message).font(.caption).foregroundStyle(.secondary)
            if !steps.connected { Button("Schritte verbinden") { steps.refresh(request: true) }.buttonStyle(PrimaryButton()) }
            else { Text("Heute verdient: \(store.ledger.life.stepBlocks[Ledger.dayKey()] ?? 0) Minuten").font(.caption.bold()).foregroundStyle(Palette.teal) }
        }.panel()
    }
}
