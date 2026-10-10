import SwiftUI
import Observation

struct SetEntry: Identifiable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var previous: String
    var isDone = false
    var isPR = false
}

struct ExerciseLog: Identifiable {
    let id = UUID()
    let name: String
    let muscle: String
    var sets: [SetEntry]
    /// Best weight x reps volume seen so far, used for PR detection.
    var bestVolume: Double
}

@MainActor @Observable
final class WorkoutSession {
    var exercises: [ExerciseLog] = [
        ExerciseLog(name: "Panca piana", muscle: "Petto", sets: [
            SetEntry(weight: 80, reps: 8, previous: "77.5 × 8"),
            SetEntry(weight: 80, reps: 8, previous: "77.5 × 8"),
            SetEntry(weight: 80, reps: 8, previous: "77.5 × 7"),
        ], bestVolume: 620),
        ExerciseLog(name: "Croci ai cavi", muscle: "Petto", sets: [
            SetEntry(weight: 15, reps: 12, previous: "15 × 12"),
            SetEntry(weight: 15, reps: 12, previous: "15 × 11"),
        ], bestVolume: 180),
        ExerciseLog(name: "French press", muscle: "Tricipiti", sets: [
            SetEntry(weight: 30, reps: 10, previous: "27.5 × 10"),
            SetEntry(weight: 30, reps: 10, previous: "27.5 × 10"),
        ], bestVolume: 275),
    ]

    var restRemaining = 0
    var restTotal = 90
    var prTrigger = 0
    private var restTask: Task<Void, Never>?

    var isResting: Bool { restRemaining > 0 }

    var completedSets: Int { exercises.flatMap(\.sets).filter(\.isDone).count }
    var totalSets: Int { exercises.flatMap(\.sets).count }
    var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isDone).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Called after any change so the Watch link can push a fresh snapshot.
    var onUpdate: (() -> Void)?

    var snapshot: WorkoutSnapshot {
        WorkoutSnapshot(
            title: "Push",
            restSeconds: restTotal,
            exercises: exercises.map { ex in
                .init(id: ex.id, name: ex.name, sets: ex.sets.map {
                    .init(id: $0.id, weight: $0.weight, reps: $0.reps, isDone: $0.isDone)
                })
            }
        )
    }

    /// Applies a set toggle coming from the Watch; ignored if already in that state.
    func apply(_ toggle: SetToggle) {
        guard let e = exercises.firstIndex(where: { $0.id == toggle.exerciseID }),
              let s = exercises[e].sets.firstIndex(where: { $0.id == toggle.setID }),
              exercises[e].sets[s].isDone != toggle.isDone else { return }
        withAnimation(Motion.snappy) { self.toggle(exercise: e, set: s) }
    }

    func toggle(exercise e: Int, set s: Int) {
        defer { onUpdate?() }
        var set = exercises[e].sets[s]
        set.isDone.toggle()
        if set.isDone {
            let volume = set.weight * Double(set.reps)
            if volume > exercises[e].bestVolume {
                set.isPR = true
                exercises[e].bestVolume = volume
                prTrigger += 1
            }
            startRest(seconds: restTotal)
        } else {
            set.isPR = false
        }
        exercises[e].sets[s] = set
    }

    func startRest(seconds: Int) {
        restTask?.cancel()
        restTotal = seconds
        restRemaining = seconds
        restTask = Task { [weak self] in
            while let self, self.restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.restRemaining -= 1
            }
        }
    }

    func adjustRest(by delta: Int) {
        restRemaining = max(0, restRemaining + delta)
        restTotal = max(restTotal, restRemaining)
    }

    func skipRest() {
        restTask?.cancel()
        restRemaining = 0
    }
}
