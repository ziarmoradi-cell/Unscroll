import SwiftUI

struct SleepView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var screenTime: ScreenTimeController
    @EnvironmentObject var sound: SoundPlayer
    @StateObject private var alarm = WakeAlarm()
    @State private var wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var selectedSound = Soundscape.ocean
    @State private var soundMinutes = 30
    @State private var message: String?
    @State private var endNight = false
    private var wakeDate: Date { Calendar.current.nextDate(after: Date(), matching: Calendar.current.dateComponents([.hour, .minute], from: wake), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(28800) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Text("DEIN ABENDRITUAL").font(.caption.bold()).tracking(3); Spacer(); Image(systemName: "moon.stars").font(.title) }
                    Text("Der Tag darf\nleiser werden.").font(.system(size: 38, weight: .medium, design: .serif))
                    Text("Weniger Feed. Mehr Ruhe. Morgen ist auch noch ein Tag.").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    if let until = store.ledger.life.nightUntil, until > Date() {
                        Text("Nachtpause bis \(until.formatted(date: .omitted, time: .shortened))").font(.headline)
                        Button("Nachtpause beenden") { endNight = true }.buttonStyle(.bordered).tint(.white)
                    } else {
                        Button("Nachtpause starten") {
                            screenTime.blockNow(); guard screenTime.error == nil else { return }
                            store.mutate { $0.life.nightUntil = wakeDate }
                            sound.play(selectedSound, until: Date().addingTimeInterval(Double(soundMinutes * 60)))
                        }.buttonStyle(PrimaryButton())
                    }
                    Text("Pausiert das Einlösen bis zu deiner Aufstehzeit. Laufendes Restbudget verfällt. Die Sperre ausgewählter Apps benötigt Bildschirmzeit.").font(.caption).foregroundStyle(.white.opacity(0.65))
                }.padding(26).foregroundStyle(.white).background(Palette.night, in: RoundedRectangle(cornerRadius: 28))
                VStack(alignment: .leading, spacing: 16) {
                    Label("Dein Morgen", systemImage: "sunrise").font(.title3.bold())
                    DatePicker("Spätestens aufstehen", selection: $wake, displayedComponents: .hourAndMinute)
                    Text(alarm.supported ? "30 Minuten vorher und zur Aufstehzeit: ein eigener Weckton, der innerhalb von 29 Sekunden deutlich kräftiger und dichter wird. Beide Alarme lassen sich einzeln stoppen. Keine Schlafphasenmessung." : "30-Minuten-Fenster: ein sanfter Hinweis zum Start und ein zweiter zur Aufstehzeit. Keine Schlafphasenmessung.").font(.subheadline).foregroundStyle(.secondary)
                    if alarm.supported {
                        if let date = alarm.scheduled { Label("Aktiv: " + date.formatted(date: .abbreviated, time: .shortened), systemImage: "alarm.fill").font(.subheadline) }
                        Button("Systemwecker setzen") { Task { await alarm.schedule(at: wakeDate) } }.buttonStyle(PrimaryButton()).disabled(alarm.busy)
                        if alarm.scheduled != nil { Button("Beide Wecker löschen") { alarm.cancel() } }
                        if let message = alarm.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                    } else {
                    Button("Morgen-Erinnerungen setzen") {
                        let end = wakeDate
                        Task {
                            do {
                                if end.timeIntervalSinceNow > 1800 { try await ReminderService.schedule(id: "wake-soft", at: end.addingTimeInterval(-1800), title: "Langsam in den Tag", body: "Dein Aufstehfenster beginnt. Lass dir einen ruhigen Moment.") }
                                else { ReminderService.cancel("wake-soft") }
                                try await ReminderService.schedule(id: "wake-final", at: end, title: "Guten Morgen", body: "Deine geplante Aufstehzeit ist da.")
                                message = "Erinnerungen für \(end.formatted(date: .abbreviated, time: .shortened)) gesetzt."
                            } catch { message = error.localizedDescription }
                        }
                    }.buttonStyle(.bordered)
                    Button("Erinnerungen löschen") { ReminderService.cancel("wake-soft"); ReminderService.cancel("wake-final"); message = "Morgen-Erinnerungen gelöscht." }
                    if let message { Text(message).font(.caption) }
                    Text("Wichtig: Dies sind Benachrichtigungen, kein verlässlicher Wecker. Lautlos und Fokus können sie unterdrücken. Stelle deinen Wecker zusätzlich in Apples Uhr-App. Der Systemwecker in Unscroll benötigt iOS 26 und einen Build mit Xcode 26 oder neuer.").font(.caption).foregroundStyle(.secondary)
                    }
                }.panel()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Klang zum Abschalten").font(.headline)
                    Picker("Abschalten nach", selection: $soundMinutes) { ForEach([15, 30, 60], id: \.self) { Text("\($0) Min.").tag($0) } }.pickerStyle(.segmented)
                }.panel()
                SoundCard(selected: $selectedSound, until: Date().addingTimeInterval(Double(soundMinutes * 60)))
                VStack(alignment: .leading, spacing: 18) {
                    Text("Ein kleines Abendritual").font(.title3.bold())
                    ForEach(["Handy außer Reichweite legen", "Gedanken für morgen aufschreiben", "Licht und Bildschirm dimmen"], id: \.self) { item in
                        Button {
                            store.mutate { ledger in
                                var done = ledger.life.routine[Ledger.dayKey()] ?? []
                                if done.contains(item) { done.remove(item) } else { done.insert(item) }
                                ledger.life.routine[Ledger.dayKey()] = done
                            }
                        } label: { HStack { Image(systemName: (store.ledger.life.routine[Ledger.dayKey()] ?? []).contains(item) ? "checkmark.circle.fill" : "circle"); Text(item).multilineTextAlignment(.leading) } }.buttonStyle(.plain)
                    }
                }.panel()
            }.padding(22)
        }.page().toolbar(.hidden, for: .navigationBar).onAppear { alarm.refresh(); if let saved = UserDefaults.standard.object(forKey: "wakePreference") as? Date { wake = saved } }
        .onChange(of: wake) { _, value in UserDefaults.standard.set(value, forKey: "wakePreference") }
        .confirmationDialog("Nachtpause vorzeitig beenden?", isPresented: $endNight, titleVisibility: .visible) {
            Button("Nachtpause beenden", role: .destructive) { store.mutate { $0.life.nightUntil = nil }; sound.stop() }
        }
    }
}
