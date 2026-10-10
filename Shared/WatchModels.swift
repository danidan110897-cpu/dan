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
}

struct SetToggle: Codable {
    var exerciseID: UUID
    var setID: UUID
    var isDone: Bool
}

enum WatchKey {
    static let snapshot = "snapshot"
    static let toggle = "toggle"
}
