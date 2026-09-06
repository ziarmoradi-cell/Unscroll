import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var screenTime = ScreenTimeController()
    @State private var workout: Exercise?
    @State private var picker = false
    @State private var minutes = 5
    @State private var confirmBlock = false

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Verdiene deine Bildschirmzeit.").font(.largeTitle.bold())
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(store.ledger.balanceSeconds / 60) min \(store.ledger.balanceSeconds % 60) s")
                                .font(.system(size: 42, weight: .black, design: .rounded)).foregroundStyle(.mint)
                            Text("Dein verfügbares Guthaben")
                        }.card()
                        trainingCards
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Social Media", systemImage: "lock.shield").font(.title2.bold())
                            if !screenTime.approved {
                                Text("Erlaube Bildschirmzeit, um deine ausgewählten Apps zu sperren.")
                                Button("Bildschirmzeit erlauben") { Task { await screenTime.authorize() } }.buttonStyle(.borderedProminent)
                            } else {
                                Button("Apps auswählen") { picker = true }.disabled(screenTime.grant != nil)
                                if let grant = screenTime.grant {
                                    Text("Freischaltung aktiv: \(grant.seconds / 60) Minuten Nutzungsbudget")
                                    Text("Zählt die Nutzung deiner gewählten Apps. Automatische Sperre nach Verbrauch, spätestens nach 24 Stunden.")
                                        .font(.footnote).foregroundStyle(.secondary)
                                    Button("Jetzt wieder sperren") { confirmBlock = true }.buttonStyle(.bordered)
                                } else {
                                    Text(screenTime.hasSelection ? "Ausgewählte Apps sind gesperrt." : "Wähle Apps aus, die du durch Training freischalten möchtest.")
                                    Stepper("\(minutes) Minuten freischalten", value: $minutes, in: 1...120)
                                    Button("Guthaben einlösen") { screenTime.unlock(minutes: minutes); store.reload() }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(!screenTime.hasSelection || store.ledger.balanceSeconds < minutes * 60)
                                    Text("Das gewählte Budget wird vom Guthaben abgezogen. Ein vorzeitig beendetes oder abgelaufenes Budget wird nicht erstattet.")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }.card()
                    }.padding()
                }.navigationTitle("UNSCROLL")
            }.tabItem { Label("Heute", systemImage: "sun.max") }
            NavigationStack {
                ScrollView { VStack(spacing: 20) { trainingCards; tips }.padding() }.navigationTitle("Training")
            }.tabItem { Label("Training", systemImage: "figure.strengthtraining.traditional") }
            NavigationStack {
                List {
                    Section("Persönliche Rekorde") {
                        ForEach(Exercise.allCases) { exercise in
                            LabeledContent(exercise.title, value: "\(Int(store.ledger.record(exercise))) \(exercise == .plank ? "s am Stück" : "Wdh.")")
                        }
                    }
                    Section("Belohnungen") {
                        rewardPicker("Liegestütz", exercise: .pushUps)
                        rewardPicker("Kniebeuge", exercise: .squats)
                        Text("Plank: 10 erkannte Sekunden = 1 Minute")
                    }
                    Section("Letzte Trainings") {
                        if store.ledger.workouts.isEmpty { Text("Dein erstes Training wartet.") }
                        ForEach(Array(store.ledger.workouts.reversed().prefix(30))) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.exercise.title).font(.headline)
                                Text(entry.exercise == .plank ? "\(Int(entry.plankSeconds)) s · PR im Training: \(Int(entry.bestHold)) s" : "\(entry.reps) Wiederholungen")
                                Text("+\(entry.creditedSeconds / 60) min \(entry.creditedSeconds % 60) s · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section("Datenschutz") { Text("Kamerabilder werden nur auf deinem iPhone verarbeitet und nicht gespeichert oder hochgeladen. Trainingswerte und Rekorde bleiben lokal.") }
                }.navigationTitle("Profil")
            }.tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .tint(.mint).preferredColorScheme(.dark)
        .sheet(item: $workout, onDismiss: { store.reload() }) { WorkoutView(exercise: $0).environmentObject(store) }
        .familyActivityPicker(isPresented: $picker, selection: $screenTime.selection)
        .onChange(of: picker) { wasOpen, isOpen in if wasOpen && !isOpen { screenTime.saveSelection() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.reload(); screenTime.refresh() } }
        .alert("Hinweis", isPresented: Binding(get: { store.error != nil || screenTime.error != nil }, set: { if !$0 { store.error = nil; screenTime.error = nil } })) {
            Button("OK") { store.error = nil; screenTime.error = nil }
        } message: { Text(store.error ?? screenTime.error ?? "") }
        .confirmationDialog("Freischaltung beenden? Restliches Nutzungsbudget verfällt.", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Jetzt sperren", role: .destructive) { screenTime.blockNow(); store.reload() }
        }
    }

    private var trainingCards: some View {
        VStack(spacing: 12) {
            ForEach(Exercise.allCases) { exercise in
                Button { workout = exercise } label: {
                    HStack {
                        Image(systemName: exercise.symbol).font(.title).frame(width: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(exercise.title).font(.headline)
                            Text("PR: \(Int(store.ledger.record(exercise))) \(exercise == .plank ? "s am Stück" : "Wdh.")").font(.caption)
                        }
                        Spacer(); Image(systemName: "play.circle.fill").font(.title)
                    }.card()
                }.buttonStyle(.plain)
            }
        }
    }
    private var tips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("So klappt die Erkennung").font(.title2.bold())
            Text("1. Handy aufrecht und stabil abstellen.\n2. Seitlich zur Kamera trainieren.\n3. Ganzen Körper und Füße im Bild halten.\n4. Gute Beleuchtung und nur eine Person im Bild.\n5. Jede Wiederholung vollständig ausführen.")
            Text("Beim Plank pausiert die Gesamtzeit, wenn du die Haltung verlässt. Der Rekord zählt nur die längste durchgehend erkannte Haltung.")
            Text("Weniger scrollen: Schalte unnötige Benachrichtigungen aus und lege dein Handy außerhalb deiner Reichweite ab.")
        }.card()
    }
    private func rewardPicker(_ title: String, exercise: Exercise) -> some View {
        Picker(title, selection: Binding(get: {
            exercise == .pushUps ? store.ledger.pushUpSeconds : store.ledger.squatSeconds
        }, set: { value in
            store.setRewards(pushUps: exercise == .pushUps ? value : store.ledger.pushUpSeconds,
                             squats: exercise == .squats ? value : store.ledger.squatSeconds)
        })) {
            ForEach([15, 30, 60, 120], id: \.self) { Text("\($0) s / Wdh.").tag($0) }
        }
    }
}

private extension View {
    func card() -> some View {
        self.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.07, green: 0.13, blue: 0.17), in: RoundedRectangle(cornerRadius: 20))
    }
}
