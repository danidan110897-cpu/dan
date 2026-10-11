import Foundation
import ActivityKit

/// Starts, updates and ends the workout Live Activity. Failures are silent: the in-app flow is the source of truth.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<RestAttributes>?

    /// Switch in Settings; on by default.
    static var enabled: Bool { UserDefaults.standard.object(forKey: "liveActivity") as? Bool ?? true }

    /// At launch: a Live Activity left behind by a workout that no longer exists should not stay on the lock screen.
    func endIfIdle() {
        guard WorkoutSession.savedSummary == nil else { return }
        for old in Activity<RestAttributes>.activities {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func startOrUpdate(workout: String, phase: String, headline: String, endDate: Date, done: Int, total: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, Self.enabled else { return }
        // After the app was closed and reopened the old Live Activity is still on screen: keep using it.
        if activity == nil { activity = Activity<RestAttributes>.activities.first }
        let state = RestAttributes.ContentState(endDate: endDate, setsDone: done, setsTotal: total, phase: phase, headline: headline)
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(120))
        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(attributes: RestAttributes(workoutName: workout), content: content)
        }
    }

    func end() {
        guard let current = activity else { return }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
