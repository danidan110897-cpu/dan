import Foundation
import ActivityKit
import AppIntents

/// Live Activity shown on the Lock Screen and Dynamic Island for the whole guided workout:
/// get ready -> work (with a "Fatto" button) -> rest.
struct RestAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var setsDone: Int
        var setsTotal: Int
        /// "ready", "work" or "rest".
        var phase: String = "rest"
        var headline: String = ""
    }

    var workoutName: String
}

/// Bridge between the Lock Screen button and the running workout in the app process.
enum LiveBridge {
    @MainActor static var onDone: (() -> Void)?
}

/// Runs inside the app when "Fatto" is pressed on the Live Activity.
struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Serie fatta"

    func perform() async throws -> some IntentResult {
        await MainActor.run { LiveBridge.onDone?() }
        return .result()
    }
}
