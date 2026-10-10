import Foundation
import UserNotifications

/// Local weekly reminder (Sunday 10:00) to take a progress photo and read the weekly summary. Nothing leaves the phone.
enum Reminders {
    private static let id = "pulse.weekly.photo"

    /// One notification per scheduled weekday at 18:00, e.g. "Oggi: Push".
    @MainActor
    static func scheduleTraining(routines: [Routine]) async {
        let center = UNUserNotificationCenter.current()
        let old = (1...7).map { "pulse.train.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for weekday in 1...7 {
            guard let routine = routines.first(where: { $0.weekdays.contains(weekday) && !$0.items.isEmpty }) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Oggi: \(routine.name)"
            content.body = "\(routine.items.count) esercizi, circa \(routine.estimatedMinutes) minuti. Quando vuoi, si parte."
            content.sound = .default
            var when = DateComponents()
            when.weekday = weekday
            when.hour = 18
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "pulse.train.\(weekday)", content: content, trigger: trigger))
        }
    }

    static func cancelTraining() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (1...7).map { "pulse.train.\($0)" })
    }

    @discardableResult
    static func setWeeklyPhoto(enabled: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { return true }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Riepilogo della settimana"
        content.body = "Fai la foto progressi e guarda come è andata la settimana."
        content.sound = .default

        var when = DateComponents()
        when.weekday = 1
        when.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return true
    }
}
