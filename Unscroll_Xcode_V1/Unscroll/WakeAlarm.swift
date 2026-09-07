import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

@MainActor final class WakeAlarm: ObservableObject {
    @Published var message: String?
    @Published var busy = false
    @Published var scheduled: Date?
    var supported: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }
    private static let softID = UUID(uuidString: "D64E0311-94AF-4CE9-A301-000000000001")!
    private static let finalID = UUID(uuidString: "D64E0311-94AF-4CE9-A301-000000000002")!
    func refresh() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do {
                let active = try AlarmManager.shared.alarms
                if active.contains(where: { $0.id == Self.finalID }) {
                    scheduled = UserDefaults.standard.object(forKey: "wakeAlarmDate") as? Date
                } else { scheduled = nil }
            } catch { message = error.localizedDescription }
        }
        #endif
    }
    func schedule(at end: Date) async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            busy = true; defer { busy = false }
            do {
                guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
                    message = "Erlaube Wecker in den iPhone-Einstellungen für Unscroll."; return
                }
                try cancelExisting()
                let manager = AlarmManager.shared
                try Self.writeGentleTone()
                let finalAttributes = AlarmAttributes<WakeMetadata>(presentation: AlarmPresentation(alert: AlarmPresentation.Alert(title: "Guten Morgen", stopButton: AlarmButton(text: "Aufstehen", textColor: .white, systemImageName: "sun.max.fill"))), tintColor: Palette.teal)
                _ = try await manager.schedule(id: Self.finalID, configuration: AlarmManager.AlarmConfiguration<WakeMetadata>(schedule: .fixed(end), attributes: finalAttributes, sound: .named("UnscrollGentle.wav")))
                if end.timeIntervalSinceNow > 1800 {
                    let softAttributes = AlarmAttributes<WakeMetadata>(presentation: AlarmPresentation(alert: AlarmPresentation.Alert(title: "Sanft in den Tag", stopButton: AlarmButton(text: "Noch etwas Ruhe", textColor: .white, systemImageName: "moon.fill"))), tintColor: Palette.teal)
                    _ = try await manager.schedule(id: Self.softID, configuration: AlarmManager.AlarmConfiguration<WakeMetadata>(schedule: .fixed(end.addingTimeInterval(-1800)), attributes: softAttributes, sound: .named("UnscrollGentle.wav")))
                }
                UserDefaults.standard.set(end, forKey: "wakeAlarmDate")
                scheduled = end; message = "Systemwecker aktiv. Der zweite Alarm bleibt bestehen, wenn du den sanften Start stoppst."
                ReminderService.cancel("wake-soft"); ReminderService.cancel("wake-final")
            } catch {
                try? cancelExisting(); scheduled = nil
                message = "Wecker konnte nicht vollständig gesetzt werden: \(error.localizedDescription)"
            }
        }
        #endif
    }
    func cancel() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do { try cancelExisting(); scheduled = nil; UserDefaults.standard.removeObject(forKey: "wakeAlarmDate"); message = "Beide Wecker gelöscht." }
            catch { message = error.localizedDescription; refresh() }
        }
        #endif
    }
    #if canImport(AlarmKit)
    @available(iOS 26.0, *) private func cancelExisting() throws {
        let manager = AlarmManager.shared
        for alarm in try manager.alarms where alarm.id == Self.softID || alarm.id == Self.finalID { try manager.cancel(id: alarm.id) }
    }
    #endif
    private static func writeGentleTone() throws {
        let directory = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Sounds")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rate = 22050; let count = rate * 29
        var data = Data(); var pcm = Data()
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            let pulse = (t * 0.5 + t * t / 116).truncatingRemainder(dividingBy: 1)
            let rise = 0.025 + 0.975 * pow(t / 29, 1.4)
            let envelope = min(1, pulse * 8) * exp(-pulse * 0.8) * rise * min(1, (29-t) * 15)
            let wave = (sin(t * 2 * .pi * 440) + 0.35 * sin(t * 2 * .pi * 660) + 0.15 * sin(t * 2 * .pi * 880)) * envelope * 0.6
            var sample = Int16(wave * 32767).littleEndian
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }
        func tag(_ s: String) { data.append(contentsOf: s.utf8) }
        func n32(_ n: Int) { var v = UInt32(n).littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func n16(_ n: Int) { var v = UInt16(n).littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        tag("RIFF"); n32(36+pcm.count); tag("WAVEfmt "); n32(16); n16(1); n16(1); n32(rate); n32(rate*2); n16(2); n16(16); tag("data"); n32(pcm.count); data.append(pcm)
        try data.write(to: directory.appendingPathComponent("UnscrollGentle.wav"), options: .atomic)
    }
}
#if canImport(AlarmKit)
@available(iOS 26.0, *) private struct WakeMetadata: AlarmMetadata {}
#endif
