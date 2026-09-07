import SwiftUI
import GameKit

struct JourneyView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var screenTime: ScreenTimeController
    @State private var days = 7
    @State private var hard = false
    @State private var start = false
    @State private var cancel = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(eyebrow: "Fortschritt, kein Perfektionismus", title: "Dein eigener Weg.", subtitle: "Kleine Entscheidungen werden zu neuen Gewohnheiten.")
                HStack(spacing: 12) {
                    Metric(value: "\(store.ledger.activeDayCount)", title: "Aktive Tage", symbol: "leaf")
                    Metric(value: "\(store.ledger.workouts.count)", title: "Trainings", symbol: "figure.strengthtraining.traditional")
                }
                VStack(alignment: .leading, spacing: 18) {
                    Label("Dein Detox-Programm", systemImage: "mountain.2").font(.title3.bold())
                    if let plan = store.ledger.life.detox, plan.active(at: Date()) {
                        Text(plan.hard ? "Konsequent offline" : "Bewusst reduzieren").font(.headline)
                        Text("Bis \(plan.end.formatted(date: .abbreviated, time: .shortened))")
                        ProgressView(value: max(0, Date().timeIntervalSince(plan.start)), total: plan.end.timeIntervalSince(plan.start))
                        Text(plan.hard ? "Keine Freischaltungen. Verdiente Zeit wartet auf dich." : "Höchstens 30 Minuten täglich einlösen; ein niedrigeres persönliches Limit gilt weiter.").font(.subheadline)
                        Button("Programm vorzeitig beenden") { cancel = true }.font(.caption)
                    } else {
                        if let plan = store.ledger.life.detox, plan.end <= Date() { Label("\(plan.days) Tage geschafft!", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.teal) }
                        Text("Schaffe bewusst Platz für Dinge, die dir fehlen.").foregroundStyle(.secondary)
                        Picker("Dauer", selection: $days) { ForEach([7, 14, 30], id: \.self) { Text("\($0) Tage").tag($0) } }.pickerStyle(.segmented)
                        Toggle("Hardcore: keine Freischaltungen", isOn: $hard)
                        Text(hard ? "Sammle weiter Guthaben, löse es erst nach dem Programm ein. Die App-Sperre benötigt Bildschirmzeit." : "Reduziere auf höchstens 30 verdiente Minuten Social Media pro Tag.").font(.caption).foregroundStyle(.secondary)
                        Button("Mein Programm starten") { start = true }.buttonStyle(PrimaryButton())
                    }
                    Text("Du behältst die Kontrolle: Ein Notausstieg ist möglich und wird als Abbruch gespeichert. iOS-Berechtigungen kannst du außerhalb von Unscroll ändern.").font(.caption).foregroundStyle(.secondary)
                }.panel()
                NavigationLink { TipsView() } label: { menu("Tipps & Tricks", detail: "Graustufen, True Tone und weniger Ablenkung", icon: "lightbulb") }.buttonStyle(.plain)
                NavigationLink { FriendsView() } label: { menu("Zusammen dranbleiben", detail: "Freunde hinzufügen und Fortschritt teilen", icon: "person.2") }.buttonStyle(.plain)
                NavigationLink { ProfileView() } label: { menu("Dein Profil & Rekorde", detail: "Ziele, Tageslimit und Trainingsverlauf", icon: "person.crop.circle") }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Deine nächsten Meilensteine").font(.headline)
                    milestone("Das erste Training", achieved: !store.ledger.workouts.isEmpty)
                    milestone("Drei aktive Tage", achieved: store.ledger.activeDayCount >= 3)
                    milestone("Eine Stunde Fokus", achieved: store.ledger.life.focusSessions.filter(\.completed).reduce(0) { $0 + $1.minutes } >= 60)
                    milestone("10.000 Schritte an einem Tag", achieved: store.ledger.life.stepTotals.values.contains { $0 >= 10000 })
                }.panel()
            }.padding(22)
        }.page().toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Detox starten? Eine laufende Freigabe endet und deren Restbudget verfällt.", isPresented: $start, titleVisibility: .visible) {
            Button("\(days) Tage starten") {
                screenTime.blockNow(); guard screenTime.error == nil else { return }
                let now = Date()
                store.mutate { $0.life.detox = DetoxPlan(start: now, end: Calendar.current.date(byAdding: .day, value: days, to: now)!, days: days, hard: hard) }
            }
        }
        .confirmationDialog("Detox abbrechen? Dein bisheriger Fortschritt bleibt, das Programm gilt als abgebrochen.", isPresented: $cancel, titleVisibility: .visible) {
            Button("Programm abbrechen", role: .destructive) { store.mutate { $0.life.detox = nil; $0.life.detoxInterrupted += 1 } }
        }
    }
    private func menu(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) { Image(systemName: icon).font(.title2).foregroundStyle(Palette.teal); VStack(alignment: .leading, spacing: 6) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.panel()
    }
    private func milestone(_ title: String, achieved: Bool) -> some View {
        Label(title, systemImage: achieved ? "checkmark.seal.fill" : "seal").foregroundStyle(achieved ? Palette.teal : Color.secondary)
    }
}
struct FriendsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var friends = FriendsManager()
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: "Zusammen leichter", title: "Deine Menschen.", subtitle: "Lade einen Freund ein. Verabredet euch zu Bewegung statt endlosem Scrollen.")
            VStack(alignment: .leading, spacing: 16) {
                Label("Game Center", systemImage: "person.2.circle").font(.title3.bold())
                Text(friends.message).font(.subheadline)
                if friends.authenticated {
                    ForEach(friends.friends, id: \.gamePlayerID) { player in Label(player.displayName, systemImage: "person.crop.circle") }
                    Button("Freunde hinzufügen") { friends.addFriend() }.buttonStyle(PrimaryButton())
                    Button("Liste aktualisieren") { friends.refresh() }
                } else { Button("Mit Game Center verbinden") { friends.connect() }.buttonStyle(PrimaryButton()).disabled(friends.busy) }
                Text("Freunde laufen über deinen Apple-Account. Trainingswerte werden nicht automatisch veröffentlicht.").font(.caption).foregroundStyle(.secondary)
            }.panel()
            VStack(alignment: .leading, spacing: 16) {
                Text("Eine kleine gemeinsame Challenge").font(.headline)
                Text("Diese Woche: dreimal 25 Minuten konzentriert arbeiten. Danach gemeinsam einen Spaziergang machen.")
                ShareLink(item: "Ich bin mit Unscroll dran: \(store.ledger.activeDayCount) aktive Tage und \(store.ledger.workouts.count) Trainings. Machst du mit? Unsere Challenge: 3 × 25 Minuten Fokus diese Woche.") { Label("Fortschritt & Einladung teilen", systemImage: "square.and.arrow.up") }
            }.panel()
        }.padding(22) }.page().navigationTitle("Freunde").navigationBarTitleDisplayMode(.inline)
    }
}
struct TipsView: View {
    @EnvironmentObject var store: AppStore
    private let tips: [(String, String, String)] = [
        ("Graustufen ausprobieren", "Einstellungen → Bedienungshilfen → Anzeige & Textgröße → Farbfilter → Graustufen. Über den Kurzbefehl für Bedienungshilfen kannst du später schneller umschalten.", "https://support.apple.com/en-us/111773"),
        ("True Tone & Night Shift", "Einstellungen → Anzeige & Helligkeit. True Tone passt die Anzeige an dein Umgebungslicht an; Night Shift verschiebt die Farben. Diese Schalter bedienst du selbst in iOS.", "https://support.apple.com/en-us/109351"),
        ("Nicht stören bewusst nutzen", "Kontrollzentrum → Fokus → Nicht stören. Wähle selbst, welche Kontakte und Apps dich erreichen dürfen.", "https://support.apple.com/guide/iphone/iph5c3f5b77b/ios"),
        ("Den Startbildschirm aufräumen", "Entferne Social-Media-Apps vom Home-Bildschirm und öffne sie gezielt über die App-Mediathek. Schalte unnötige Mitteilungen in den Einstellungen aus.", "https://support.apple.com/guide/iphone/iph7c3d96bab/ios"),
        ("Einen Zweck vor dem Öffnen", "Notiere vor dem Öffnen, was du erledigen willst. Schließe die App, wenn es erledigt ist. Eine kurze Liste hilft gegen zielloses Weiterscrollen.", "")
    ]
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: "Dein digitales Werkzeugset", title: "Weniger Reize.\nMehr Absicht.", subtitle: "Probiere einen Tipp aus. Behalte, was zu dir passt.")
            ForEach(tips.indices, id: \.self) { index in
                let tip = tips[index]
                VStack(alignment: .leading, spacing: 14) {
                    Text(tip.0).font(.title3.bold()); Text(tip.1).font(.subheadline).foregroundStyle(.secondary)
                    if let url = URL(string: tip.2), !tip.2.isEmpty { Link("Apple-Anleitung", destination: url) }
                    Button {
                        store.mutate { if $0.life.checkedTips.contains(tip.0) { $0.life.checkedTips.remove(tip.0) } else { $0.life.checkedTips.insert(tip.0) } }
                    } label: { Label(store.ledger.life.checkedTips.contains(tip.0) ? "Ausprobiert" : "Als ausprobiert markieren", systemImage: store.ledger.life.checkedTips.contains(tip.0) ? "checkmark.circle.fill" : "circle") }.font(.caption.bold())
                }.panel()
            }
        }.padding(22) }.page().navigationTitle("Tipps & Tricks").navigationBarTitleDisplayMode(.inline)
    }
}
struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        Form {
            Section("Dein Profil") {
                TextField("Name", text: Binding(get: { store.ledger.life.profile.name }, set: { value in store.mutate { $0.life.profile.name = value } }))
                TextField("Alter (optional)", text: Binding(get: { store.ledger.life.profile.age.map(String.init) ?? "" }, set: { value in store.mutate { $0.life.profile.age = Int(value).flatMap { (1...120).contains($0) ? $0 : nil } } })).keyboardType(.numberPad)
                Picker("Ziel", selection: Binding(get: { store.ledger.life.profile.goal }, set: { value in store.mutate { $0.life.profile.goal = value } })) { ForEach(PersonalGoal.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Schwierigkeit", selection: Binding(get: { store.ledger.life.profile.difficulty }, set: { value in store.mutate { $0.life.profile.difficulty = value } })) { ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) } }
                Stepper("Tageslimit: \(store.ledger.life.profile.dailyBudget) Min.", value: Binding(get: { store.ledger.life.profile.dailyBudget }, set: { value in store.mutate { $0.life.profile.dailyBudget = value } }), in: 5...120, step: 5)
                Text("Detox und aktive Pausen gelten auch dann, wenn du dein persönliches Limit änderst.").font(.caption)
                Button("Intro erneut ansehen") { store.mutate { $0.life.profile.completedIntro = false } }
            }
            Section("Persönliche Rekorde") {
                ForEach(Exercise.allCases) { exercise in LabeledContent(exercise.title, value: "\(Int(store.ledger.record(exercise))) \(exercise == .plank ? "s am Stück" : "Wdh.")") }
            }
            Section("Deine Trainings") {
                if store.ledger.workouts.isEmpty { Text("Dein erstes Training wartet.").foregroundStyle(.secondary) }
                ForEach(Array(store.ledger.workouts.reversed().prefix(30))) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.exercise.title).font(.headline)
                        Text(entry.exercise == .plank ? "\(Int(entry.plankSeconds)) Sekunden" : "\(entry.reps) Wiederholungen")
                        Text("+\(entry.creditedSeconds / 60) Min. \(entry.creditedSeconds % 60) Sek. · \(entry.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Fokus") {
                Text("\(store.ledger.life.focusSessions.filter(\.completed).count) abgeschlossene Sessions")
                Text("\(store.ledger.life.focusSessions.filter(\.interrupted).count) unterbrochene Sessions")
                Text("\(store.ledger.life.detoxInterrupted) abgebrochene Detox-Programme")
            }
            Section("Deine Daten") { Text("Profil, Schritte, Notizen, Guthaben und Trainings bleiben lokal auf deinem iPhone. Kamerabilder werden weder gespeichert noch hochgeladen. Game Center nutzt deinen Apple-Account, wenn du es verbindest. Beim Teilen entscheidest du selbst, wer deinen Fortschritt bekommt.").font(.footnote) }
        }.scrollContentBackground(.hidden).page().navigationTitle("Dein Profil").navigationBarTitleDisplayMode(.inline)
    }
}
