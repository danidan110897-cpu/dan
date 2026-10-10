import SwiftData
import Foundation

enum MuscleGroup: String, CaseIterable, Identifiable, Codable {
    case chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core, fullBody, cardio
    var id: String { rawValue }
    var label: String {
        switch self {
        case .chest: "Petto"
        case .back: "Schiena"
        case .shoulders: "Spalle"
        case .biceps: "Bicipiti"
        case .triceps: "Tricipiti"
        case .quads: "Quadricipiti"
        case .hamstrings: "Femorali"
        case .glutes: "Glutei"
        case .calves: "Polpacci"
        case .core: "Addome"
        case .fullBody: "Corpo intero"
        case .cardio: "Cardio"
        }
    }
    var symbol: String {
        switch self {
        case .cardio: "figure.run"
        case .core: "figure.core.training"
        case .fullBody: "figure.strengthtraining.functional"
        case .quads, .hamstrings, .glutes, .calves: "figure.strengthtraining.traditional"
        default: "dumbbell.fill"
        }
    }
}

enum Equipment: String, CaseIterable, Identifiable, Codable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell
    var id: String { rawValue }
    var label: String {
        switch self {
        case .barbell: "Bilanciere"
        case .dumbbell: "Manubri"
        case .machine: "Macchinario"
        case .cable: "Cavi"
        case .bodyweight: "Corpo libero"
        case .kettlebell: "Kettlebell"
        }
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var key: String
    var name: String
    var muscleRaw: String
    var equipmentRaw: String
    var isCustom: Bool

    init(key: String, name: String, muscle: MuscleGroup, equipment: Equipment, isCustom: Bool = false) {
        self.key = key
        self.name = name
        self.muscleRaw = muscle.rawValue
        self.equipmentRaw = equipment.rawValue
        self.isCustom = isCustom
    }

    var muscle: MuscleGroup { MuscleGroup(rawValue: muscleRaw) ?? .fullBody }
    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .bodyweight }
}

@Model
final class Routine {
    var name: String
    var createdAt: Date
    var restSeconds: Int
    @Relationship(deleteRule: .cascade) var items: [RoutineItem] = []

    init(name: String, restSeconds: Int = 90) {
        self.name = name
        self.createdAt = .now
        self.restSeconds = restSeconds
    }

    var sortedItems: [RoutineItem] { items.sorted { $0.order < $1.order } }

    var estimatedMinutes: Int {
        let seconds = items.reduce(0) { $0 + $1.sets * (45 + restSeconds) }
        return max(Int((Double(seconds) / 60).rounded()), 1)
    }
}

@Model
final class RoutineItem {
    var order: Int
    var exercise: Exercise?
    var sets: Int
    var reps: Int
    var weight: Double
    /// 0 means no superset; items sharing the same non-zero value are performed together.
    var supersetGroup: Int
    var note: String

    init(order: Int, exercise: Exercise, sets: Int = 3, reps: Int = 10, weight: Double = 0) {
        self.order = order
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.supersetGroup = 0
        self.note = ""
    }
}

@Model
final class WorkoutLog {
    var date: Date
    var name: String
    var durationSeconds: Int
    var volume: Double
    @Relationship(deleteRule: .cascade) var entries: [LogEntry] = []

    init(date: Date, name: String, durationSeconds: Int, volume: Double) {
        self.date = date
        self.name = name
        self.durationSeconds = durationSeconds
        self.volume = volume
    }

    var sortedEntries: [LogEntry] { entries.sorted { $0.order < $1.order } }
}

@Model
final class LogEntry {
    var exerciseKey: String
    var exerciseName: String
    var muscleRaw: String
    var order: Int
    @Relationship(deleteRule: .cascade) var sets: [LogSet] = []

    init(exerciseKey: String, exerciseName: String, muscleRaw: String, order: Int) {
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.muscleRaw = muscleRaw
        self.order = order
    }

    var sortedSets: [LogSet] { sets.sorted { $0.order < $1.order } }
}

@Model
final class LogSet {
    var order: Int
    var weight: Double
    var reps: Int
    var isPR: Bool

    init(order: Int, weight: Double, reps: Int, isPR: Bool) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isPR = isPR
    }

    /// Epley estimate of the one-rep max.
    var estimatedOneRM: Double { weight * (1 + Double(reps) / 30) }
}

func formatWeight(_ w: Double) -> String {
    w.formatted(.number.precision(.fractionLength(0...1)))
}
