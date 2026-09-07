import SwiftUI

struct FocusView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var screenTime: ScreenTimeController
    @EnvironmentObject var sound: SoundPlayer
    @State private var duration = 25
    @State private var intention = ""
    @State private var strict = true
    @State private var selectedSound = Soundscape.brown
    @State private var cancel = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(eyebrow: "Ein Ding nach dem anderen", title: "Raum für Fokus.", subtitle: "Lege fest, was jetzt zählt. Der Rest darf warten.")
                if let session = store.ledger.life.activeFocus {
                    VStack(spacing: 22) {
                        Image(systemName: "scope").font(.system(size: 45, weight: .ultraLight))
                        Text(session.intention.isEmpty ? "Zeit für dich" : session.intention).font(.title3)
                        Text(timerInterval: session.start...max(session.start, session.end), countsDown: true).font(.system(size: 58, weight: .light, design: .rounded)).monospacedDigit()
                        Text(session.strict ? "Freischalten pausiert bis zum Ende" : "Deine bewusste Fokuszeit").font(.caption)
                        Button("Session vorzeitig beenden") { cancel = true }.font(.subheadline)
                    }.frame(maxWidth: .infinity).padding(28).foregroundStyle(.white).background(Palette.teal, in: RoundedRectangle(cornerRadius: 28))
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Was möchtest du schaffen?").font(.headline)
                        TextField("Zum Beispiel: ein Kapitel lesen", text: $intention).textFieldStyle(.roundedBorder)
                        Picker("Dauer", selection: $duration) { ForEach([15, 25, 50], id: \.self) { Text("\($0) Min.").tag($0) } }.pickerStyle(.segmented)
                        Toggle("Apps währenddessen gesperrt halten", isOn: $strict)
                        Text("Im strengen Fokus kannst du keine Zeit einlösen. Eine laufende Freigabe endet; deren Restbudget verfällt. Die App-Sperre benötigt Bildschirmzeit und ausgewählte Apps.").font(.caption).foregroundStyle(.secondary)
                        Button("Meine Fokuszeit starten") { start() }.buttonStyle(PrimaryButton())
                    }.panel()
                }
                SoundCard(selected: $selectedSound, until: store.ledger.life.activeFocus?.end)
                VStack(alignment: .leading, spacing: 14) {
                    Label("Nicht stören", systemImage: "moon").font(.headline)
                    Text("Öffne das Kontrollzentrum → Fokus → Nicht stören. iOS lässt Unscroll diesen Systemschalter nicht selbst umlegen.").font(.subheadline)
                    Link("Apple-Anleitung öffnen", destination: URL(string: "https://support.apple.com/guide/iphone/iph5c3f5b77b/ios")!)
                }.panel()
                VStack(alignment: .leading, spacing: 12) {
                    Label("Gedankenparkplatz", systemImage: "square.and.pencil").font(.headline)
                    Text("Etwas kommt dir dazwischen? Schreib es hier auf und mach später weiter.").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: Binding(get: { store.ledger.life.parkingNote }, set: { value in store.mutate { $0.life.parkingNote = value } })).frame(height: 100).scrollContentBackground(.hidden)
                }.panel()
            }.padding(22)
        }.page().toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Fokus beenden? Diese Session wird als unterbrochen gespeichert.", isPresented: $cancel, titleVisibility: .visible) {
            Button("Session beenden", role: .destructive) { store.mutate { $0.abandonFocus() }; sound.stop(); ReminderService.cancel("focus") }
        }
    }
    private func start() {
        if strict { screenTime.blockNow(); if screenTime.error != nil { return } }
        let end = Date().addingTimeInterval(Double(duration * 60))
        store.mutate { $0.life.activeFocus = FocusSession(start: Date(), end: end, intention: intention, strict: strict) }
        guard store.error == nil else { return }
        sound.play(selectedSound, until: end)
    }
}
struct SoundCard: View {
    @EnvironmentObject var sound: SoundPlayer
    @Binding var selected: Soundscape
    var until: Date?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Dein Hintergrund", systemImage: "waveform").font(.headline)
            Picker("Klang", selection: $selected) { ForEach(Soundscape.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
            HStack {
                Button(sound.playing == .silence ? "Klang starten" : "Klang stoppen") { if sound.playing == .silence { sound.play(selected, until: until ?? Date().addingTimeInterval(1800)) } else { sound.stop() } }.buttonStyle(.bordered)
                Spacer(); Image(systemName: "speaker.wave.2")
            }
            Slider(value: $sound.volume, in: 0...1).accessibilityLabel("Lautstärke")
            Text(sound.playing == .silence ? "Offline verfügbar · mit Abschalttimer" : "Aktiv: \(sound.playing.rawValue)").font(.caption).foregroundStyle(.secondary)
            if selected == .ocean {
                Link("Wellenaufnahme: Luftrum · CC BY 3.0", destination: URL(string: "https://commons.wikimedia.org/wiki/File:Oceanwavescrushing.ogg")!).font(.caption)
                Link("Lizenz · 40-Sekunden-Ausschnitt, AAC und kurze Randblenden", destination: URL(string: "https://creativecommons.org/licenses/by/3.0/")!).font(.caption2)
            }
        }.panel().onChange(of: selected) { _, new in
            if sound.playing != .silence { sound.play(new, until: until ?? Date().addingTimeInterval(1800)) }
        }
    }
}
