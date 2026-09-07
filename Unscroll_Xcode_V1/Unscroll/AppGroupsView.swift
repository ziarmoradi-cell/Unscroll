import SwiftUI
import FamilyControls

struct AppGroupsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var screenTime: ScreenTimeController
    @State private var draft = FamilyActivitySelection()
    @State private var picker = false
    @State private var name = "Social Media"
    @State private var status: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(eyebrow: "Deine App-Pakete", title: "Gemeinsam sperren.", subtitle: "Einmal zusammenstellen, später mit einem Tipp aktivieren.")
                VStack(alignment: .leading, spacing: 14) {
                    Label("Social-Media-Paket", systemImage: "app.badge").font(.title3.bold())
                    Text("Instagram · Snapchat · X · TikTok · YouTube").font(.headline)
                    Text("Wähle diese Apps einmal in Apples Auswahl aus. Apple verlangt dafür deine persönliche Auswahl; Apps lassen sich nicht automatisch vorab markieren. Danach bleibt das Paket gespeichert. Weitere Apps kannst du dazunehmen.").font(.subheadline).foregroundStyle(.secondary)
                    if !screenTime.approved {
                        Button("Bildschirmzeit erlauben") { Task { await screenTime.authorize() } }.buttonStyle(PrimaryButton())
                    } else {
                        TextField("Paketname", text: $name).textFieldStyle(.roundedBorder)
                        Button("Paket auswählen / weitere Apps") { picker = true }.buttonStyle(PrimaryButton())
                        Text("Auswahl: \(draft.applicationTokens.count) Apps · \(draft.categoryTokens.count) Kategorien · \(draft.webDomainTokens.count) Websites").font(.caption)
                        Button("Paket speichern und sperren") { save() }.buttonStyle(.bordered).disabled(draft.applicationTokens.isEmpty && draft.categoryTokens.isEmpty)
                    }
                    if let status { Text(status).font(.caption).foregroundStyle(Palette.teal) }
                    Text("Während einer Pause kannst du weitere Apps hinzufügen; bestehende Sperren lassen sich dann nicht aus der Auswahl entfernen.").font(.caption).foregroundStyle(.secondary)
                }.panel()
                ForEach((store.ledger.life.savedAppGroups ?? [:]).keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(key, systemImage: "square.stack.3d.up").font(.headline)
                        Button("Dieses Paket zur Sperre hinzufügen") {
                            guard let data = store.ledger.life.savedAppGroups?[key], let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
                            draft = screenTime.selection
                            draft.applicationTokens.formUnion(saved.applicationTokens)
                            draft.categoryTokens.formUnion(saved.categoryTokens)
                            draft.webDomainTokens.formUnion(saved.webDomainTokens)
                            screenTime.selection = draft; screenTime.saveSelection(); store.reload()
                            if screenTime.error == nil { status = "Paket zur gespeicherten Sperrauswahl hinzugefügt." }
                        }
                    }.panel()
                }
            }.padding(22)
        }.page().navigationTitle("App-Pakete").navigationBarTitleDisplayMode(.inline)
            .familyActivityPicker(isPresented: $picker, selection: $draft)
            .onAppear { draft = screenTime.selection }
    }
    private func save() {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { status = "Gib dem Paket einen Namen."; return }
        screenTime.selection = draft; screenTime.saveSelection()
        guard screenTime.error == nil else { return }
        do {
            let data = try JSONEncoder().encode(draft)
            store.mutate { ledger in
                var groups = ledger.life.savedAppGroups ?? [:]; groups[key] = data; ledger.life.savedAppGroups = groups
            }
            if store.error == nil { status = "Paket gespeichert. Die ausgewählten Apps sind zur Sperre eingerichtet." }
        } catch { store.error = error.localizedDescription }
    }
}
