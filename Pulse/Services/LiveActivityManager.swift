import Foundation
import ActivityKit

/// Starts, updates and ends the workout Live Activity. Failures are silent: the in-app flow is the source of truth.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<RestAttributes>?

    func startOrUpdate(workout: String, phase: String, headline: String, endDate: Date, done: Int, total: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
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
