import Foundation
import UserNotifications

/// Local weekly reminder (Sunday 10:00) to take a progress photo and read the weekly summary. Nothing leaves the phone.
enum Reminders {
    private static let id = "pulse.weekly.photo"

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
