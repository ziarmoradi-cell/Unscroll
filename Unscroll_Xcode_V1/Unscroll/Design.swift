import SwiftUI

enum Palette {
    static let paper = Color(red: 0.965, green: 0.952, blue: 0.926)
    static let ink = Color(red: 0.09, green: 0.17, blue: 0.20)
    static let teal = Color(red: 0.15, green: 0.39, blue: 0.35)
    static let peach = Color(red: 0.94, green: 0.72, blue: 0.56)
    static let night = Color(red: 0.10, green: 0.12, blue: 0.22)
}
extension View {
    func panel() -> some View { padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 26)) }
    func page() -> some View { frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper).foregroundStyle(Palette.ink) }
}
struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(.white).background(Palette.teal.opacity(!enabled ? 0.35 : configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct PageHeading: View {
    let eyebrow: String; let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(3).foregroundStyle(Palette.teal)
            Text(title).font(.system(size: 37, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).foregroundStyle(.secondary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
    }
}
struct Metric: View {
    let value: String; let title: String; let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Palette.teal)
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).panel()
    }
}
struct IntroView: View {
    @EnvironmentObject var store: AppStore
    @State private var page = 0
    @State private var profile = PersonalProfile()
    @State private var age = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack { Text("unscroll").font(.title2.bold()); Spacer(); Text("\(page + 1) / 4").font(.caption).foregroundStyle(.secondary) }
                ProgressView(value: Double(page + 1), total: 4).tint(Palette.teal)
                Image(systemName: ["leaf", "person.crop.circle", "scope", "slider.horizontal.3"][page])
                    .font(.system(size: 58, weight: .ultraLight)).foregroundStyle(Palette.teal).frame(height: 120).frame(maxWidth: .infinity)
                if page == 0 {
                    PageHeading(eyebrow: "Mehr Leben. Weniger Feed.", title: "Deine Zeit gehört dir.", subtitle: "Bewege dich. Finde deinen Fokus. Schalte bewusst ab.")
                    VStack(alignment: .leading, spacing: 20) {
                        Label("Bewegung wird zu Bildschirmzeit", systemImage: "figure.walk")
                        Label("Ruhe für Kopf und Abend", systemImage: "moon.stars")
                        Label("Kleine Schritte. Dein eigener Rhythmus.", systemImage: "sparkles")
                    }.panel()
                } else if page == 1 {
                    PageHeading(eyebrow: "Ganz persönlich", title: "Wie heißt du?", subtitle: "Dein Profil bleibt auf diesem iPhone. Dein Alter ist freiwillig.")
                    TextField("Dein Vorname", text: $profile.name).textContentType(.givenName).padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
                    TextField("Alter (optional)", text: $age).keyboardType(.numberPad).padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
                } else if page == 2 {
                    PageHeading(eyebrow: "Deine Richtung", title: "Was ist dir wichtig?", subtitle: "Du kannst dein Ziel später jederzeit ändern.")
                    ForEach(PersonalGoal.allCases) { goal in
                        Button { profile.goal = goal } label: { HStack { Label(goal.rawValue, systemImage: goal.symbol); Spacer(); Image(systemName: profile.goal == goal ? "checkmark.circle.fill" : "circle") }.panel() }.buttonStyle(.plain)
                    }
                } else {
                    PageHeading(eyebrow: "Dein Tempo", title: "Klein anfangen. Dranbleiben.", subtitle: "Die Schwierigkeit setzt Tagesziele, keine strengeren Vorgaben für deine Körperhaltung.")
                    ForEach(Difficulty.allCases) { level in
                        Button { profile.difficulty = level; profile.dailyBudget = level.dailyBudget } label: {
                            HStack { VStack(alignment: .leading, spacing: 6) { Text(level.rawValue).font(.headline); Text("\(level.stepGoal) Schritte · \(level.repGoal) Wdh.\nMax. \(level.dailyBudget) Min. Social Media / Tag · +\(level.rewardPerRep) s Guthaben / Wdh.").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: profile.difficulty == level ? "checkmark.circle.fill" : "circle") }.panel()
                        }.buttonStyle(.plain)
                    }
                    Text("Guthaben verdienst du durch Bewegung. Berechtigungen fragen wir erst, wenn du eine Funktion nutzt.").font(.footnote).foregroundStyle(.secondary)
                }
                Button(page == 3 ? "Mein neues Kapitel starten" : "Weiter") {
                    if page < 3 { withAnimation { page += 1 } }
                    else { profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines); profile.age = Int(age).flatMap { (1...120).contains($0) ? $0 : nil }; profile.completedIntro = true; store.mutate { $0.life.profile = profile } }
                }.buttonStyle(PrimaryButton()).disabled(page == 1 && profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if page > 0 { Button("Zurück") { withAnimation { page -= 1 } }.frame(maxWidth: .infinity) }
            }.padding(26)
        }.page().onAppear { profile = store.ledger.life.profile; age = profile.age.map(String.init) ?? "" }
    }
}
