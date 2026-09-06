import Foundation
import UserNotifications
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

enum Reminders {
    static func schedule(hour: Int) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
            throw UnscrollModel.problem("Mitteilungen sind nicht erlaubt. Bitte in den iPhone-Einstellungen aktivieren.")
        }
        let evening = UNMutableNotificationContent()
        evening.title = "Dein Abend gehört dir"
        evening.body = "Handy zur Seite. Zeit für etwas, das dir guttut."
        evening.sound = .default
        try await center.add(UNNotificationRequest(identifier: "unscroll.evening", content: evening,
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)))
        let weekly = UNMutableNotificationContent()
        weekly.title = "Dein Wochenrückblick"
        weekly.body = "Schau dir deine Bewegung, verdiente Zeit und Ausnahmen in Unscroll an."
        weekly.sound = .default
        try await center.add(UNNotificationRequest(identifier: "unscroll.weekly", content: weekly,
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 18, minute: 0, weekday: 1), repeats: true)))
    }
    static func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["unscroll.evening", "unscroll.weekly"]) }
}

enum WakeAlarm {
    static let id = UUID(uuidString: "84E33D35-17D6-49A1-BD1D-CCBA99FE3111")!
    static func schedule(hour: Int, minute: Int) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            let permission = try await manager.requestAuthorization()
            guard permission == .authorized else { throw UnscrollModel.problem("Wecker-Zugriff wurde nicht erlaubt.") }
            let alert = AlarmPresentation.Alert(title: "Guten Morgen. Dein Tag wartet.", stopButton: AlarmButton(text: "Aufstehen", textColor: .white, systemImageName: "sun.max"))
            let attributes = AlarmAttributes<WakeMetadata>(presentation: AlarmPresentation(alert: alert), metadata: WakeMetadata(), tintColor: .green)
            let relative = Alarm.Schedule.Relative(time: .init(hour: hour, minute: minute), repeats: .weekly([.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]))
            let configuration = AlarmManager.AlarmConfiguration<WakeMetadata>.alarm(schedule: .relative(relative), attributes: attributes, stopIntent: nil, secondaryIntent: nil, sound: .named("gentle-wake.wav"))
            _ = try await manager.schedule(id: id, configuration: configuration)
            return
        }
        #endif
        throw UnscrollModel.problem("Der persönliche Wecker benötigt iOS 26 oder neuer.")
    }
    static func cancel() throws {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { try AlarmManager.shared.cancel(id: id); return }
        #endif
        throw UnscrollModel.problem("AlarmKit ist auf diesem iPhone nicht verfügbar.")
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct WakeMetadata: AlarmMetadata {}
#endif
