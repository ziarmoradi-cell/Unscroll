import SwiftUI
import FamilyControls
import Charts

private let mint = Color(red: 0.70, green: 0.96, blue: 0.39)

struct RootView: View {
    @EnvironmentObject var model: UnscrollModel
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Heute", systemImage: "sun.max") }
            NavigationStack { TrainingView() }.tabItem { Label("Bewegen", systemImage: "figure.strengthtraining.functional") }
            NavigationStack { ReportView() }.tabItem { Label("Rückblick", systemImage: "chart.bar.xaxis") }
            NavigationStack { FriendsView() }.tabItem { Label("Gemeinsam", systemImage: "person.2") }
            NavigationStack { ProfileView() }.tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .task { model.refresh() }
        .onChange(of: phase) { _, phase in if phase == .active { model.refresh() } }
        .alert("Unscroll", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

struct HomeView: View {
    @EnvironmentObject var model: UnscrollModel
    @State private var emergency = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("DEINE ZEIT. DEINE ENTSCHEIDUNG.").font(.caption.weight(.semibold)).foregroundStyle(mint)
                Text("Hallo\(model.state.journal.profile.name.isEmpty ? "" : ", \(model.state.journal.profile.name)").\nBeweg etwas.").font(.system(size: 38, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 16) {
                    Label("Dein gemeinsames Zeitkonto", systemImage: "hourglass")
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(model.state.journal.bank)").font(.system(size: 76, weight: .bold, design: .rounded))
                        Text("Minuten bereit").foregroundStyle(.secondary)
                    }
                    if let usage = model.state.journal.usage.last, model.active {
                        Text("Aktive Freigabe: noch etwa \(max(0, usage.allocatedMinutes - usage.confirmedMinutes)) von \(usage.allocatedMinutes) Minuten.")
                        Text("Letzter iOS-Messstand · Aktualisierung kann verzögert sein.").font(.caption).foregroundStyle(.secondary)
                        Button("Messstand aktualisieren") { model.refresh() }
                    } else {
                        Button("Zeit nutzen") { model.start() }.buttonStyle(.borderedProminent)
                            .disabled(model.state.journal.bank == 0 || !model.authorized || model.state.selection.applicationTokens.isEmpty)
                    }
                    Text("Pro Freigabe bis zu 30 Minuten. Bei Abbruch oder nach 23 Stunden verfallen nicht genutzte freigegebene Minuten. Gespartes Guthaben bleibt erhalten.").font(.caption).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 28))
                if !model.authorized || model.state.selection.applicationTokens.isEmpty {
                    NavigationLink { ScreenTimeView() } label: { Label("App-Sperren einrichten", systemImage: "lock.shield") }.buttonStyle(.borderedProminent)
                }
                HStack {
                    Label("\(model.state.journal.streak()) Tage Streak", systemImage: "flame")
                    Spacer()
                    Text("\(model.state.emergencyCount) Ausnahmen").foregroundStyle(.secondary)
                }.font(.subheadline)
                NavigationLink { TrainingView() } label: { Label("Mit Bewegung Zeit verdienen", systemImage: "arrow.up.right") }.buttonStyle(.bordered)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Dein Assistent", systemImage: "sparkles").foregroundStyle(mint)
                    Text(Assistant.tip(model.state.journal)).font(.body)
                    Text("Persönliche Hinweise aus deinen Zielen und Aktivitäten.").font(.caption).foregroundStyle(.secondary)
                }.padding(20).background(mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                Button("Emergency · 5 Minuten") { emergency = true }.foregroundStyle(.secondary).disabled(model.active)
                Text(model.state.status).font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.navigationTitle("unscroll").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Fünf Minuten als Ausnahme freigeben?", isPresented: $emergency, titleVisibility: .visible) {
            Button("Emergency nutzen") { model.start(emergency: true) }
        } message: { Text("Diese Freigabe wird in deiner Wochenübersicht gezählt. Du musst dafür keine Übung machen.") }
    }
}

struct ScreenTimeView: View {
    @EnvironmentObject var model: UnscrollModel
    @State private var picker = false
    var body: some View {
        Form {
            Section("Bildschirmzeit") {
                Button(model.authorized ? "Zugriff erlaubt" : "Zugriff erlauben") { Task { await model.authorize() } }.disabled(model.authorized)
                Button("Apps auswählen") { picker = true }.disabled(!model.authorized || model.active)
                Text("\(model.selection.applicationTokens.count) Apps ausgewählt")
                Button("Auswahl speichern und sperren") { model.saveSelection() }.disabled(!model.authorized || model.active)
                Text("Wähle einzelne Apps. Alle verwenden dasselbe Zeitkonto.").font(.footnote)
            }
            Section("Sitzung verwalten") {
                Button("Sitzung beenden und sperren") { model.stop() }.disabled(!model.active)
                Text("Bereits freigegebene Restminuten werden beim Abbruch nicht zurückgebucht.").font(.footnote)
                Button("Unscroll-Sperren entfernen", role: .destructive) { model.stop(removeRestrictions: true) }
            }
        }.navigationTitle("App-Sperren")
        .familyActivityPicker(isPresented: $picker, selection: $model.selection)
    }
}

struct TrainingView: View {
    @EnvironmentObject var model: UnscrollModel
    @State private var exercise: Exercise?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Eine kleine Bewegung.\nMehr bewusste Zeit.").font(.largeTitle.bold())
                Text("Stell dein iPhone aufrecht und seitlich zu dir auf. Dein ganzer Körper muss im Bild sein. Die Kamera verarbeitet Bilder nur auf deinem Gerät.").foregroundStyle(.secondary)
                ForEach(Exercise.allCases) { item in
                    Button { exercise = item } label: {
                        HStack(spacing: 18) {
                            Image(systemName: item.symbol).font(.largeTitle).frame(width: 44)
                            VStack(alignment: .leading) {
                                Text(item.title).font(.headline)
                                Text(item == .plank ? "\(model.state.journal.profile.plankSecondsPerMinute) Sekunden → 1 Minute" : "1 Wiederholung → \(model.state.journal.profile.minutesPerRep) Minute(n)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "arrow.up.right")
                        }.padding(22).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain)
                }
                Text("Die Erkennung ist experimentell. Wähle Übungen, die für dich angenehm sind; bei Schmerzen beende sie.").font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }.navigationTitle("Bewegen")
        .fullScreenCover(item: $exercise) { WorkoutView(exercise: $0) }
    }
}

struct ReportView: View {
    @EnvironmentObject var model: UnscrollModel
    @State private var weekOffset = 0
    private var anchor: Date { Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date() }
    private var workouts: [Workout] { model.state.journal.week(at: anchor) }
    private var usage: [UsageSession] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: anchor) else { return [] }
        return model.state.journal.usage.filter { interval.contains($0.start) && $0.started }
    }
    var body: some View {
        List {
            Section {
                HStack {
                    Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Vorige Woche")
                    Spacer(); Text(weekOffset == 0 ? "Diese Woche" : "Woche vom \(anchor.formatted(date: .abbreviated, time: .omitted))"); Spacer()
                    Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }.disabled(weekOffset >= 0).accessibilityLabel("Nächste Woche")
                }.buttonStyle(.borderless)
                Text("\(workouts.reduce(0) { $0 + $1.earnedMinutes }) Minuten verdient").font(.title.bold())
                Chart(workouts) { workout in
                    BarMark(x: .value("Tag", workout.date, unit: .day), y: .value("Minuten", workout.earnedMinutes)).foregroundStyle(mint)
                }.frame(height: 160)
            }
            Section("Deine Bewegung") {
                ForEach(Exercise.allCases) { exercise in
                    LabeledContent(exercise.title, value: "\(workouts.filter { $0.exercise == exercise }.reduce(0) { $0 + $1.amount }) \(exercise.unit)")
                }
            }
            Section("Bildschirmzeit") {
                LabeledContent("Von iOS bestätigte Nutzung", value: "\(usage.reduce(0) { $0 + $1.confirmedMinutes }) Min.")
                LabeledContent("Freigegeben", value: "\(usage.reduce(0) { $0 + $1.allocatedMinutes }) Min.")
                LabeledContent("Emergency-Ausnahmen", value: "\(usage.filter(\.emergency).count)")
                Text("Nutzung aller ausgewählten Apps zusammen. Messwerte können verzögert oder unvollständig sein. Sitzungen werden der Woche ihres Starts zugeordnet.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Persönliche Rekorde · einzelne Einheit") {
                ForEach(Exercise.allCases) { exercise in
                    LabeledContent(exercise.title, value: "\(model.state.journal.workouts.filter { $0.exercise == exercise }.map(\.amount).max() ?? 0) \(exercise.unit)")
                }
            }
            Section("Letzte Einheiten") {
                if workouts.isEmpty { Text("Deine erste Einheit wartet auf dich.").foregroundStyle(.secondary) }
                ForEach(workouts.reversed()) { workout in
                    LabeledContent("\(workout.amount) \(workout.exercise.title)", value: "+\(workout.earnedMinutes) Min.")
                }
            }
        }.navigationTitle("Wochenrückblick").refreshable { model.refresh() }
    }
}

struct ProfileView: View {
    @EnvironmentObject var model: UnscrollModel
    @State private var draft = Profile()
    @State private var message: String?
    @State private var wakeTime = Date()
    var body: some View {
        Form {
            Section("Das bist du") {
                TextField("Dein Vorname", text: $draft.name).textContentType(.givenName)
                DatePicker("Geburtsdatum", selection: $draft.birthday, in: ...Date(), displayedComponents: .date)
                Text("Dein Geburtsdatum bleibt auf diesem Gerät.").font(.caption)
            }
            Section("Deine Ziele") {
                Stepper("\(draft.dailyGoal) Wiederholungen pro Tag", value: $draft.dailyGoal, in: 1...200)
                Stepper("\(draft.minutesPerRep) Minute(n) pro Wiederholung", value: $draft.minutesPerRep, in: 1...5)
                Stepper("\(draft.plankSecondsPerMinute) Plank-Sekunden pro Minute", value: $draft.plankSecondsPerMinute, in: 5...60, step: 5)
                Button("Profil und Ziele speichern") { model.saveProfile(draft) }
            }
            Section("Dein Abend") {
                Stepper("Abenderinnerung um \(draft.eveningHour):00", value: $draft.eveningHour, in: 18...23)
                Button("Abend- und Wochenhinweis aktivieren") {
                    Task {
                        do { try await Reminders.schedule(hour: draft.eveningHour); model.saveProfile(draft); message = "Erinnerungen sind eingerichtet." }
                        catch { model.error = error.localizedDescription }
                    }
                }
                Button("Erinnerungen ausschalten") { Reminders.cancel(); message = "Erinnerungen ausgeschaltet." }
                Text("True Tone kannst du in Einstellungen → Anzeige & Helligkeit einschalten. Unscroll verändert diese Einstellung nicht automatisch.").font(.footnote)
            }
            Section("Persönlicher Wecker") {
                DatePicker("Aufwachen", selection: $wakeTime, displayedComponents: .hourAndMinute)
                Button("Täglichen Wecker aktivieren") {
                    Task {
                        do {
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
                            try await WakeAlarm.schedule(hour: parts.hour ?? 7, minute: parts.minute ?? 0)
                            draft.wakeHour = parts.hour ?? 7; draft.wakeMinute = parts.minute ?? 0
                            model.saveProfile(draft); message = "Wecker eingerichtet. Bitte einmal zur Probe testen."
                        } catch { model.error = error.localizedDescription }
                    }
                }
                Button("Wecker ausschalten") { do { try WakeAlarm.cancel(); message = "Wecker ausgeschaltet." } catch { model.error = error.localizedDescription } }
                Text("Benötigt iOS 26. Der sanfte Ton muss auf dem iPhone geprüft werden.").font(.footnote)
            }
            Section { NavigationLink("App-Sperren verwalten") { ScreenTimeView() } }
            if let message { Section { Text(message) } }
        }.navigationTitle("Dein Profil")
        .onAppear {
            draft = model.state.journal.profile
            wakeTime = Calendar.current.date(bySettingHour: draft.wakeHour, minute: draft.wakeMinute, second: 0, of: Date()) ?? Date()
        }
    }
}

enum Assistant {
    static func tip(_ journal: Journal) -> String {
        let profile = journal.profile
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= profile.eveningHour || hour < 5 { return "Zeit für einen ruhigen Abend. Lege dein Handy außer Reichweite und entscheide, wann du morgen wieder online sein möchtest." }
        if profile.configured && profile.age < 18 { return "Dein Tempo zählt. Wähle ein kleines Ziel, das zu deinem Alltag passt, und sprich deine Bildschirmzeit-Regeln mit deiner Familie ab." }
        let today = journal.workouts.filter { Calendar.current.isDateInToday($0.date) && $0.exercise != .plank }.reduce(0) { $0 + $1.amount }
        if today >= profile.dailyGoal { return "Dein Tagesziel ist erreicht. Du darfst jetzt auch einfach eine Pause machen – ganz ohne Bildschirm." }
        return "Noch \(max(0, profile.dailyGoal - today)) Wiederholungen bis zu deinem Tagesziel. Wähle eine Übung, die sich heute gut anfühlt."
    }
}
