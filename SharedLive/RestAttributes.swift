import Foundation
import ActivityKit

/// Live Activity shown on the Lock Screen and Dynamic Island while resting between sets.
struct RestAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var setsDone: Int
        var setsTotal: Int
    }

    var workoutName: String
}
