import Foundation
import ActivityKit

/// Starts, updates and ends the rest-timer Live Activity. Failures are silent: the in-app timer is the source of truth.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<RestAttributes>?

    func startOrUpdate(workout: String, endDate: Date, done: Int, total: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RestAttributes.ContentState(endDate: endDate, setsDone: done, setsTotal: total)
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(30))
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
