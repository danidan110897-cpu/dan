import Foundation

/// Wire format shared by the iPhone and Watch apps.
struct WorkoutSnapshot: Codable, Equatable {
    struct Exercise: Codable, Equatable, Identifiable {
        var id: UUID
        var name: String
        var sets: [WorkoutSet]
    }
    struct WorkoutSet: Codable, Equatable, Identifiable {
        var id: UUID
        var weight: Double
        var reps: Int
        var isDone: Bool
    }

    var title: String
    var restSeconds: Int
    var exercises: [Exercise]
    /// Present while the phone runs the guided flow; the Watch mirrors it and sends taps back.
    var guided: GuidedState? = nil
}

/// What the guided flow is doing right now. Countdowns are dates, so both devices stay in sync without ticking messages.
struct GuidedState: Codable, Equatable {
    /// "ready", "work" or "rest".
    var phase: String
    var exercise: String
    var setIndex: Int
    var setCount: Int
    var reps: Int
    var weight: Double
    var endDate: Date
    var total: Int
    var next: String
}

struct SetToggle: Codable {
    var exerciseID: UUID
    var setID: UUID
    var isDone: Bool
}

enum WatchKey {
    static let snapshot = "snapshot"
    static let toggle = "toggle"
    static let action = "action"
}
