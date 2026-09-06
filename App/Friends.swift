import SwiftUI
import GameKit

@MainActor
final class FriendsModel: ObservableObject {
    @Published var signedIn = false
    @Published var message = "Melde dich mit Game Center an, um mit Freunden dranzubleiben."
    @Published var controller: UIViewController?

    func signIn() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                guard let self else { return }
                if let controller { self.controller = controller }
                self.signedIn = GKLocalPlayer.local.isAuthenticated
                self.message = error?.localizedDescription ?? (self.signedIn ? "Angemeldet als \(GKLocalPlayer.local.displayName)" : "Anmeldung noch nicht abgeschlossen.")
            }
        }
    }

    func addFriend() {
        guard let root = Self.root else { message = "Einladungsansicht nicht verfügbar."; return }
        do { try GKLocalPlayer.local.presentFriendRequestCreator(from: root) }
        catch { message = error.localizedDescription }
    }

    func publish(_ journal: Journal) async {
        guard signedIn, journal.profile.leaderboardConsent else { return }
        do {
            for exercise in Exercise.allCases {
                let score = journal.workouts.filter { $0.exercise == exercise }.reduce(0) { $0 + $1.amount }
                if score > 0 { try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["unscroll.\(exercise.rawValue)"]) }
            }
            let streak = journal.streak()
            if streak > 0 { try await GKLeaderboard.submitScore(streak, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["unscroll.streak"]) }
            message = "Deine Trainingswerte wurden übertragen."
        } catch { message = "Game Center konnte die Werte nicht übernehmen: \(error.localizedDescription)" }
    }

    static var root: UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = root?.presentedViewController { root = presented }
        return root
    }
}

struct FriendsView: View {
    @EnvironmentObject var model: UnscrollModel
    @StateObject private var friends = FriendsModel()
    @State private var dashboard = false
    var body: some View {
        List {
            Section("Zusammen ist leichter") {
                Text(friends.message)
                Button("Mit Game Center anmelden") { friends.signIn() }
                Text("Dein Profil und dein Zeitkonto funktionieren auch ohne Anmeldung.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Freunde und Vergleiche") {
                Button("Freunde hinzufügen") { friends.addFriend() }.disabled(!friends.signedIn)
                Toggle("Trainingswerte mit Game Center teilen", isOn: Binding(get: { model.state.journal.profile.leaderboardConsent }, set: { value in model.mutate { $0.journal.profile.leaderboardConsent = value } }))
                Text("Dabei werden Übungszahlen und dein Streak an Apple übermittelt und in Ranglisten angezeigt. Geburtsdatum und Bildschirmzeit bleiben lokal. Bereits geteilte Werte werden durch Ausschalten nicht gelöscht.").font(.caption).foregroundStyle(.secondary)
                Button("Meine Trainingswerte übertragen") { Task { await friends.publish(model.state.journal) } }.disabled(!friends.signedIn || !model.state.journal.profile.leaderboardConsent)
                Button("Ranglisten und Challenges öffnen") { dashboard = true }.disabled(!friends.signedIn)
                Text("Die Ranglisten müssen in App Store Connect eingerichtet sein. Es werden keine erfundenen Freunde oder Ergebnisse angezeigt.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Deine 7-Tage-Challenge") {
                Text("An sieben Tagen eine Bewegungseinheit absolvieren. Dein eigenes Tempo zählt.")
                if let start = model.state.journal.challengeStart {
                    Text("\(model.state.journal.challengeDays()) von 7 Tagen geschafft")
                    Text("Gestartet am \(start.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                }
                Button(model.state.journal.challengeStart == nil ? "Challenge starten" : "Neue Challenge starten") { model.mutate { $0.journal.challengeStart = Date() } }
                Text("Die persönliche Challenge wird lokal geführt. Ein gemeinsamer Wettkampf mit festem Start und Ende ist noch nicht angebunden.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Gemeinsam")
        .sheet(isPresented: Binding(get: { friends.controller != nil }, set: { if !$0 { friends.controller = nil } })) {
            if let controller = friends.controller { ControllerView(controller: controller) }
        }
        .sheet(isPresented: $dashboard) { GameDashboard() }
    }
}

struct ControllerView: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct GameDashboard: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(state: .default)
        controller.gameCenterDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}
    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) { dismiss() }
    }
}
