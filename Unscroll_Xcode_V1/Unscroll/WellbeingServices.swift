import SwiftUI
import CoreMotion
import AVFoundation
import UserNotifications
import GameKit

struct StepSnapshot: Equatable { var total: Int; var day: String }
@MainActor final class StepTracker: ObservableObject {
    @Published private(set) var snapshot: StepSnapshot?
    @Published var message = "Verbinde die Bewegungserkennung deines iPhones."
    @Published private(set) var connected = false
    private let pedometer = CMPedometer()
    private var token = UUID()
    func refresh(request: Bool = false) {
        guard CMPedometer.isStepCountingAvailable() else { message = "Auf diesem Gerät ist kein Schrittzähler verfügbar."; return }
        let status = CMPedometer.authorizationStatus()
        if status == .denied || status == .restricted { message = "Erlaube Bewegung & Fitness in den iPhone-Einstellungen."; connected = false; return }
        guard request || status == .authorized else { return }
        token = UUID(); let current = token
        let now = Date(); let start = Calendar.current.startOfDay(for: now); let day = Ledger.dayKey(now)
        pedometer.stopUpdates()
        pedometer.queryPedometerData(from: start, to: now) { [weak self] data, error in
            Task { @MainActor in self?.receive(data, error: error, token: current, day: day) }
        }
        pedometer.startUpdates(from: start) { [weak self] data, error in
            Task { @MainActor in self?.receive(data, error: error, token: current, day: day) }
        }
    }
    private func receive(_ data: CMPedometerData?, error: Error?, token: UUID, day: String) {
        guard self.token == token, day == Ledger.dayKey() else { return }
        if let error { message = error.localizedDescription; return }
        guard let data else { return }
        connected = true; snapshot = StepSnapshot(total: data.numberOfSteps.intValue, day: day)
        message = "Schritte von deinem iPhone · heute"
    }
}

enum Soundscape: String, CaseIterable, Identifiable {
    case silence = "Stille", white = "White Noise", brown = "Brown Noise", ocean = "Meeresrauschen"
    var id: String { rawValue }
    var symbol: String { self == .silence ? "speaker.slash" : self == .ocean ? "water.waves" : "waveform" }
}
@MainActor final class SoundPlayer: ObservableObject {
    @Published private(set) var playing = Soundscape.silence
    @Published var volume: Float = 0.25 { didSet { player?.volume = volume } }
    @Published var error: String?
    private var player: AVAudioPlayer?
    private var expiryTimer: Timer?
    private var interruption: NSObjectProtocol?
    init() {
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }
    deinit { if let interruption { NotificationCenter.default.removeObserver(interruption) } }
    func play(_ sound: Soundscape, until: Date? = nil) {
        stop(); guard sound != .silence else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: Self.noise(sound))
            player?.numberOfLoops = -1; player?.volume = volume
            guard player?.play() == true else { return }
            playing = sound
            if let until {
                expiryTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, until.timeIntervalSinceNow), repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.stop() }
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func stop() {
        expiryTimer?.invalidate(); expiryTimer = nil; player?.stop(); player = nil; playing = .silence
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    // Locally synthesized audio: no streaming, tracking or third-party assets.
    private static func noise(_ kind: Soundscape) -> Data {
        let rate = 22050; let count = rate * 12
        var samples = Data(capacity: count * 2); var brown = 0.0
        for i in 0..<count {
            let white = Double.random(in: -1...1)
            brown = (brown + white * 0.035) / 1.015
            let wave = kind == .white ? white * 0.32 : brown * (kind == .ocean ? (0.6 + 0.4 * sin(Double(i) / Double(rate) * .pi / 6)) : 1.3)
            // Brief edge envelope avoids loop clicks.
            let envelope = min(1, Double(min(i, count-1-i)) / 220)
            var sample = Int16(max(-1, min(1, wave * envelope)) * 24000).littleEndian
            withUnsafeBytes(of: &sample) { samples.append(contentsOf: $0) }
        }
        var result = Data()
        func tag(_ s: String) { result.append(contentsOf: s.utf8) }
        func u32(_ n: Int) { var v = UInt32(n).littleEndian; withUnsafeBytes(of: &v) { result.append(contentsOf: $0) } }
        func u16(_ n: Int) { var v = UInt16(n).littleEndian; withUnsafeBytes(of: &v) { result.append(contentsOf: $0) } }
        tag("RIFF"); u32(36+samples.count); tag("WAVEfmt "); u32(16); u16(1); u16(1); u32(rate); u32(rate*2); u16(2); u16(16)
        tag("data"); u32(samples.count); result.append(samples); return result
    }
}

@MainActor enum ReminderService {
    static func schedule(id: String, at date: Date, title: String, body: String) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else {
            throw NSError(domain: "Unscroll", code: 1, userInfo: [NSLocalizedDescriptionKey: "Benachrichtigungen sind nicht erlaubt."])
        }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false))
        try await center.add(request)
    }
    static func cancel(_ id: String) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
}

@MainActor final class FriendsManager: NSObject, ObservableObject, GKFriendRequestComposeViewControllerDelegate {
    @Published var friends: [GKPlayer] = []
    @Published var authenticated = false
    @Published var message = "Verbinde Game Center, um mit Freunden dranzubleiben."
    @Published var busy = false
    func connect() {
        busy = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                guard let self else { return }; self.busy = false
                if let controller { self.present(controller); return }
                self.authenticated = GKLocalPlayer.local.isAuthenticated
                if let error { self.message = error.localizedDescription }
                else if self.authenticated { self.refresh() }
                else { self.message = "Melde dich in den iPhone-Einstellungen bei Game Center an." }
            }
        }
    }
    func refresh() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLocalPlayer.local.loadFriends { [weak self] players, error in
            Task { @MainActor in
                self?.friends = players ?? []
                self?.message = error?.localizedDescription ?? ((players ?? []).isEmpty ? "Dein erster Trainingsbuddy wartet." : "Deine Game-Center-Freunde")
            }
        }
    }
    func addFriend() {
        guard authenticated else { connect(); return }
        guard GKFriendRequestComposeViewController.canSendFriendRequests() else { message = "Freundschaftsanfragen sind für diesen Account nicht verfügbar."; return }
        let controller = GKFriendRequestComposeViewController(); controller.composeViewDelegate = self; present(controller)
    }
    func friendRequestComposeViewControllerDidFinish(_ viewController: GKFriendRequestComposeViewController) {
        viewController.dismiss(animated: true) { [weak self] in self?.refresh() }
    }
    private func present(_ controller: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { message = "Bitte versuche es erneut."; return }
        while let next = root.presentedViewController { root = next }
        root.present(controller, animated: true)
    }
}
