import SwiftUI
import CoreMotion

struct OnboardingView: View {
    @EnvironmentObject var model: UnscrollModel
    @State private var page = 0
    @State private var draft = Profile()
    private let titles = ["Mehr Leben.\nWeniger Scrollen.", "Wie heißt du?", "Wann hast du Geburtstag?", "Dein Tempo.\nDein Modus.", "Ein kleines Ziel.\nEin guter Anfang."]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("unscroll ↗").font(.title.bold())
                ProgressView(value: Double(page + 1), total: 5)
                Text("Schritt \(page + 1) von 5").font(.caption).foregroundStyle(.secondary)
                Text(titles[page]).font(.largeTitle.bold())
                switch page {
                case 0:
                    Text("Verdiene bewusste Bildschirmzeit mit Bewegung. Mit Übungen, Planks und deinen täglichen Schritten.")
                    Text("Wir richten Unscroll gemeinsam ein. Deine Angaben bleiben auf deinem Gerät.").foregroundStyle(.secondary)
                case 1:
                    TextField("Dein Vorname", text: $draft.name).textContentType(.givenName).textFieldStyle(.roundedBorder)
                case 2:
                    DatePicker("Geburtsdatum", selection: $draft.birthday, in: ...Date(), displayedComponents: .date)
                    Text("Für persönliche Hinweise. Dein Geburtstag wird nicht mit Freunden geteilt.").font(.caption)
                case 3:
                    ForEach(Difficulty.allCases) { mode in
                        Button { draft.difficulty = mode } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(mode.title).font(.headline)
                                    Text("1 Wiederholung · 30 Sek. Plank · 1.000 Schritte → \(mode.multiplier) Min.").font(.caption)
                                }
                                Spacer()
                                Image(systemName: draft.mode == mode ? "checkmark.circle.fill" : "circle")
                            }.padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                    Text("Der Modus bestimmt deine Gutschrift, nicht wie hart du trainieren musst.").font(.caption)
                default:
                    Stepper("\(draft.dailyGoal) Wiederholungen pro Tag", value: $draft.dailyGoal, in: 1...200)
                    Text("Planks und Schritte zählen separat. Passe dein Ziel jederzeit an.")
                    Text("Bildschirmzeit, Bewegung und Kamera erlaubst du erst, wenn du die jeweilige Funktion verwendest.").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    if page > 0 { Button("Zurück") { page -= 1 }.buttonStyle(.bordered) }
                    Spacer()
                    Button(page == 4 ? "Los geht’s" : "Weiter") {
                        if page == 4 { model.saveProfile(draft) } else { page += 1 }
                    }.buttonStyle(.borderedProminent)
                    .disabled(page == 1 && draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(28)
        }
    }
}

@MainActor
final class StepReader: ObservableObject {
    @Published var busy = false
    @Published var message: String?
    private let pedometer = CMPedometer()
    func refresh(_ model: UnscrollModel) {
        guard !busy else { return }
        guard CMPedometer.isStepCountingAvailable() else { message = "Schrittzählung ist auf diesem Gerät nicht verfügbar."; return }
        let status = CMPedometer.authorizationStatus()
        guard status != .denied && status != .restricted else {
            message = "Erlaube Bewegung & Fitness in den iPhone-Einstellungen für Unscroll."; return
        }
        busy = true; message = nil
        let now = Date()
        let start = model.state.journal.stepCalendar.startOfDay(for: now)
        pedometer.queryPedometerData(from: start, to: now) { [weak self] data, error in
            let steps = data?.numberOfSteps.intValue
            let failure = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                self.busy = false
                guard failure == nil, let steps else { self.message = failure ?? "Noch keine Schrittdaten verfügbar."; return }
                model.mutate { state in
                    state.journal.stepsEnabled = true
                    state.journal.updateSteps(steps, at: now)
                }
                self.message = "iPhone-Schritte aktualisiert."
            }
        }
    }
}

struct StepsCard: View {
    @EnvironmentObject var model: UnscrollModel
    @Environment(\.scenePhase) private var phase
    @StateObject private var reader = StepReader()
    var body: some View {
        let day = model.state.journal.stepDay()
        let blocks = max(0, day.steps / 1000 - day.claimedBlocks)
        VStack(alignment: .leading, spacing: 14) {
            Label("Deine Schritte heute", systemImage: "figure.walk").font(.headline)
            Text("\(day.steps.formatted())").font(.largeTitle.bold())
            Text("1.000 Schritte → \(model.state.journal.profile.mode.multiplier) Min. · \(model.state.journal.profile.mode.title)")
            ProgressView(value: Double(day.steps % 1000), total: 1000)
            Text("\(1000 - day.steps % 1000) Schritte bis zum nächsten vollen Tausender.").font(.caption)
            Button(reader.busy ? "Wird gelesen …" : model.state.journal.stepsEnabled == true ? "Schritte aktualisieren" : "Schritte verbinden") { reader.refresh(model) }
                .disabled(reader.busy)
            Button("\(blocks * model.state.journal.profile.mode.multiplier) Minuten gutschreiben") {
                model.mutate { state in _ = state.journal.claimSteps() }
            }.buttonStyle(.borderedProminent).disabled(blocks == 0 || reader.busy)
            Text("Heute bereits \(day.minutes) Min. gutgeschrieben. Jeder volle Tausender zählt einmal. Restschritte gelten bis Tagesende. Gezählt werden Schritte mit deinem iPhone; keine Apple-Watch-Synchronisierung.").font(.caption).foregroundStyle(.secondary)
            if let message = reader.message { Text(message).font(.caption) }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
        .task { if model.state.journal.stepsEnabled == true { reader.refresh(model) } }
        .onChange(of: phase) { _, new in if new == .active && model.state.journal.stepsEnabled == true { reader.refresh(model) } }
    }
}
