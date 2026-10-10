import SwiftUI
import SwiftData
import Observation

struct SessionSet: Identifiable, Equatable {
    var id = UUID()
    var weight: Double
    var reps: Int
    var previous: String
    var isDone = false
    var isPR = false
}

struct SessionExercise: Identifiable {
    let id = UUID()
    let key: String
    let name: String
    let muscle: MuscleGroup
    let equipment: Equipment
    var sets: [SessionSet]
    /// Best weight x reps seen in past sessions. Nil when there is no history, so a first session never counts as a PR.
    var bestVolume: Double?
    var superset: Int
    /// Why the starting weight was chosen (progressive overload), shown under the exercise name.
    var hint: String? = nil
}

/// A workout in progress. Built from a routine plus past history, saved to SwiftData at the end.
@MainActor @Observable
final class WorkoutSession {
    var title: String
    var exercises: [SessionExercise]
    let startedAt = Date()

    var restRemaining = 0
    var restTotal: Int
    var prTrigger = 0
    private var restTask: Task<Void, Never>?

    /// Called after any change so the Watch link can push a fresh snapshot.
    var onUpdate: (() -> Void)?

    init(title: String, exercises: [SessionExercise], restSeconds: Int) {
        self.title = title
        self.exercises = exercises
        self.restTotal = restSeconds
    }

    static func make(from routine: Routine, context: ModelContext, lighter: Bool = false) -> WorkoutSession {
        let logs = (try? context.fetch(FetchDescriptor<WorkoutLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        var last: [String: [LogSet]] = [:]
        var best: [String: Double] = [:]
        for log in logs {
            for entry in log.entries {
                if last[entry.exerciseKey] == nil { last[entry.exerciseKey] = entry.sortedSets }
                for s in entry.sets {
                    best[entry.exerciseKey] = max(best[entry.exerciseKey] ?? 0, s.weight * Double(s.reps))
                }
            }
        }

        var exercises: [SessionExercise] = []
        for item in routine.sortedItems {
            guard let ex = item.exercise else { continue }
            let prev = last[ex.key] ?? []
            var (increment, hint) = overload(prev: prev, targetReps: item.reps, equipment: ex.equipment)
            if lighter {
                increment = 0
                hint = "Versione leggera: una serie in meno e nessun aumento di carico."
            }
            let sets = (0..<max(item.sets - (lighter ? 1 : 0), 1)).map { i -> SessionSet in
                let ref = i < prev.count ? prev[i] : prev.last
                return SessionSet(
                    weight: (ref?.weight ?? item.weight) + increment,
                    reps: ref?.reps ?? item.reps,
                    previous: ref.map { "\(formatWeight($0.weight)) × \($0.reps)" } ?? "—"
                )
            }
            exercises.append(SessionExercise(key: ex.key, name: ex.name, muscle: ex.muscle, equipment: ex.equipment, sets: sets,
                                             bestVolume: best[ex.key], superset: item.supersetGroup, hint: hint))
        }
        return WorkoutSession(title: routine.name, exercises: exercises, restSeconds: routine.restSeconds)
    }

    /// Double progression: when every set of the last session reached the target reps, add the smallest sensible jump.
    private static func overload(prev: [LogSet], targetReps: Int, equipment: Equipment) -> (Double, String?) {
        guard !prev.isEmpty, equipment != .bodyweight, (prev.map(\.weight).max() ?? 0) > 0 else { return (0, nil) }
        if prev.allSatisfy({ $0.reps >= targetReps }) {
            let step: Double = switch equipment {
            case .dumbbell: 2
            case .kettlebell: 4
            default: 2.5
            }
            return (step, "Hai chiuso tutte le serie a \(targetReps) o più ripetizioni: oggi prova +\(formatWeight(step)) kg.")
        }
        return (0, "Tieni lo stesso carico finché non chiudi \(targetReps) ripetizioni in tutte le serie.")
    }

    var isResting: Bool { restRemaining > 0 }
    var completedSets: Int { exercises.flatMap(\.sets).filter(\.isDone).count }
    var totalSets: Int { exercises.flatMap(\.sets).count }
    var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isDone).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var snapshot: WorkoutSnapshot {
        WorkoutSnapshot(
            title: title,
            restSeconds: restTotal,
            exercises: exercises.map { ex in
                .init(id: ex.id, name: ex.name, sets: ex.sets.map {
                    .init(id: $0.id, weight: $0.weight, reps: $0.reps, isDone: $0.isDone)
                })
            }
        )
    }

    /// Applies a set toggle coming from the Watch; ignored if already in that state.
    func apply(_ change: SetToggle) {
        guard let e = exercises.firstIndex(where: { $0.id == change.exerciseID }),
              let s = exercises[e].sets.firstIndex(where: { $0.id == change.setID }),
              exercises[e].sets[s].isDone != change.isDone else { return }
        withAnimation(Motion.snappy) { toggle(exerciseID: change.exerciseID, setID: change.setID) }
    }

    func toggle(exerciseID: UUID, setID: UUID) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }),
              let s = exercises[e].sets.firstIndex(where: { $0.id == setID }) else { return }
        defer { onUpdate?() }
        var set = exercises[e].sets[s]
        set.isDone.toggle()
        if set.isDone {
            let volume = set.weight * Double(set.reps)
            if let best = exercises[e].bestVolume, volume > best {
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

    func addSet(to exerciseID: UUID) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let ref = exercises[e].sets.last
        exercises[e].sets.append(SessionSet(weight: ref?.weight ?? 0, reps: ref?.reps ?? 10, previous: "—"))
        onUpdate?()
    }

    func startRest(seconds: Int) {
        restTask?.cancel()
        restTotal = seconds
        restRemaining = seconds
        updateActivity()
        restTask = Task { [weak self] in
            while let self, self.restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.restRemaining -= 1
            }
            LiveActivityManager.shared.end()
        }
    }

    func adjustRest(by delta: Int) {
        restRemaining = max(0, restRemaining + delta)
        restTotal = max(restTotal, restRemaining)
        if restRemaining > 0 { updateActivity() } else { LiveActivityManager.shared.end() }
    }

    func skipRest() {
        restTask?.cancel()
        restRemaining = 0
        LiveActivityManager.shared.end()
    }

    private func updateActivity() {
        LiveActivityManager.shared.startOrUpdate(
            workout: title,
            endDate: Date().addingTimeInterval(TimeInterval(restRemaining)),
            done: completedSets,
            total: totalSets
        )
    }

    /// Saves completed sets as a WorkoutLog. Returns false when nothing was completed.
    @discardableResult
    func save(to context: ModelContext) -> Bool {
        skipRest()
        var entries: [LogEntry] = []
        for (i, ex) in exercises.enumerated() {
            let done = ex.sets.filter(\.isDone)
            guard !done.isEmpty else { continue }
            let entry = LogEntry(exerciseKey: ex.key, exerciseName: ex.name, muscleRaw: ex.muscle.rawValue, order: i)
            entry.sets = done.enumerated().map { LogSet(order: $0.offset, weight: $0.element.weight, reps: $0.element.reps, isPR: $0.element.isPR) }
            entries.append(entry)
        }
        guard !entries.isEmpty else { return false }
        let log = WorkoutLog(date: startedAt, name: title,
                             durationSeconds: Int(Date().timeIntervalSince(startedAt)),
                             volume: totalVolume)
        context.insert(log)
        log.entries = entries
        try? context.save()
        // With a paired Watch the Watch records the workout (with heart rate); otherwise write it from the phone.
        if !Connectivity.shared.hasWatch {
            let (start, end) = (startedAt, Date())
            Task { await HealthStore.shared.saveWorkout(start: start, end: end) }
        }
        return true
    }
}

extension WorkoutSession: Hashable {
    nonisolated static func == (lhs: WorkoutSession, rhs: WorkoutSession) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
