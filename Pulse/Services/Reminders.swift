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

/// One-shot local notifications at the end of a rest or work phase, so a locked phone (and a paired Watch) still taps you.
enum PhaseAlerts {
    private static let id = "pulse.phase"

    /// Switch in Settings; on by default. Only the end of a rest is announced, and only while the phone is locked or the app is closed.
    static var enabled: Bool { UserDefaults.standard.object(forKey: "phaseAlerts") as? Bool ?? true }

    static let category = "pulse.phase.actions"
    static let doneAction = "pulse.phase.done"

    /// Registers the "Fatto" button so it shows on the notification, including on a paired Watch.
    static func registerCategory() {
        let done = UNNotificationAction(identifier: doneAction, title: "Fatto / Avanti", options: [])
        let cat = UNNotificationCategory(identifier: category, actions: [done], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    static func requestPermission() async {
        registerCategory()
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func schedule(title: String, body: String, after seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard seconds > 0, enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active
        content.categoryIdentifier = category
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        clearDelivered()
    }

    /// Removes an alert that is already on the lock screen, e.g. when you come back to the app.
    static func clearDelivered() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}

/// Routes a tap on the notification button (phone or Watch) to the running workout.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == PhaseAlerts.doneAction else { return }
        await MainActor.run { LiveBridge.onDone?() }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The app is open: the screen already shows everything, so no banner or sound on top of it.
        []
    }
}
