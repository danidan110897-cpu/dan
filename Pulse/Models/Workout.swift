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
    private(set) var restEnd = Date()
    private var ticker: Task<Void, Never>?

    // Guided mode: the app walks set by set (get ready -> work -> rest -> next set) on its own.
    enum Phase: Equatable { case idle, getReady, work, rest }
    var guided = false
    var phase: Phase = .idle
    var phaseEnd = Date()
    var phaseTotal = 1
    var timeUp = false
    var allDone = false
    /// When on, a set is marked done by itself once its estimated time is over.
    var autoComplete = false
    var startTrigger = 0
    var timeUpTrigger = 0
    /// Average seconds per repetition (controlled tempo), used to estimate how long a set lasts.
    static let secondsPerRep = 3.5

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
            },
            guided: guidedState
        )
    }

    private var guidedState: GuidedState? {
        guard guided, phase != .idle, let ex = currentExercise, let set = currentSet else { return nil }
        let name = switch phase { case .getReady: "ready"; case .work: "work"; default: "rest" }
        return GuidedState(
            phase: name, exercise: ex.name, setIndex: currentSetNumber, setCount: ex.sets.count,
            reps: set.reps, weight: set.weight,
            endDate: phase == .rest ? restEnd : phaseEnd, total: phase == .rest ? restTotal : phaseTotal,
            next: upcomingDescription
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
        if guided, set.isDone { afterGuidedSet() }
    }

    func addSet(to exerciseID: UUID) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let ref = exercises[e].sets.last
        exercises[e].sets.append(SessionSet(weight: ref?.weight ?? 0, reps: ref?.reps ?? 10, previous: "—"))
        onUpdate?()
    }

    func startRest(seconds: Int) {
        restTotal = seconds
        restEnd = Date().addingTimeInterval(TimeInterval(seconds))
        restRemaining = seconds
        updateActivity()
        let next = upcomingDescription
        PhaseAlerts.schedule(title: "Recupero finito", body: next, after: seconds)
        startTicker()
    }

    func adjustRest(by delta: Int) {
        restEnd = restEnd.addingTimeInterval(TimeInterval(delta))
        restRemaining = max(0, Int(ceil(restEnd.timeIntervalSinceNow)))
        restTotal = max(restTotal, restRemaining)
        if restRemaining > 0 {
            updateActivity()
            PhaseAlerts.schedule(title: "Recupero finito", body: upcomingDescription, after: restRemaining)
        } else {
            restEnded()
        }
    }

    func skipRest() {
        guard restRemaining > 0 else { return }
        restRemaining = 0
        PhaseAlerts.cancel()
        if guided, phase == .rest, cursor != nil { enterGetReady(seconds: 3) } else { LiveActivityManager.shared.end() }
    }

    // MARK: Guided flow

    /// First set that is not done yet, in routine order.
    var cursor: (e: Int, s: Int)? {
        for (e, ex) in exercises.enumerated() {
            if let s = ex.sets.firstIndex(where: { !$0.isDone }) { return (e, s) }
        }
        return nil
    }

    var currentExercise: SessionExercise? { cursor.map { exercises[$0.e] } }
    var currentSet: SessionSet? { cursor.map { exercises[$0.e].sets[$0.s] } }
    var currentSetNumber: Int { cursor.map { $0.s + 1 } ?? 0 }

    var upcomingDescription: String {
        guard let c = cursor else { return "Allenamento finito" }
        let ex = exercises[c.e]
        return "Prossima: \(ex.name), serie \(c.s + 1)/\(ex.sets.count)"
    }

    func beginGuided() {
        guided = true
        allDone = false
        Task { await PhaseAlerts.requestPermission() }
        if cursor == nil { endGuided(allDone: true) } else { enterGetReady(seconds: 5) }
    }

    func stopGuided() {
        guided = false
        phase = .idle
        PhaseAlerts.cancel()
        onUpdate?()
    }

    /// The one action every surface (button, Lock Screen, Watch) maps to: move to the next step of the flow.
    func primaryAction() {
        switch phase {
        case .getReady: startWork()
        case .work: completeWork()
        case .rest: skipRest()
        case .idle: break
        }
    }

    func completeWork() {
        guard phase == .work, let c = cursor else { return }
        toggle(exerciseID: exercises[c.e].id, setID: exercises[c.e].sets[c.s].id)
    }

    func nudge(weight delta: Double = 0, reps: Int = 0) {
        guard let c = cursor else { return }
        exercises[c.e].sets[c.s].weight = max(0, exercises[c.e].sets[c.s].weight + delta)
        exercises[c.e].sets[c.s].reps = max(1, exercises[c.e].sets[c.s].reps + reps)
        onUpdate?()
    }

    /// Call when the app comes back to the foreground: timers are date based, so just catch up.
    func resync() {
        if tick() { startTicker() }
    }

    private func enterGetReady(seconds: Int) {
        phase = .getReady
        phaseTotal = seconds
        phaseEnd = Date().addingTimeInterval(TimeInterval(seconds))
        timeUp = false
        updateActivity()
        startTicker()
    }

    private func startWork() {
        guard guided, let c = cursor else { endGuided(allDone: true); return }
        let reps = exercises[c.e].sets[c.s].reps
        let seconds = max(10, Int((Double(reps) * Self.secondsPerRep).rounded()) + 3)
        phase = .work
        phaseTotal = seconds
        phaseEnd = Date().addingTimeInterval(TimeInterval(seconds))
        timeUp = false
        startTrigger += 1
        updateActivity()
        if !autoComplete {
            PhaseAlerts.schedule(title: "Tempo!", body: "Finita la serie? Premi Fatto.", after: seconds)
        }
        startTicker()
    }

    private func afterGuidedSet() {
        if cursor == nil {
            endGuided(allDone: true)
        } else {
            phase = .rest
        }
    }

    private func endGuided(allDone done: Bool) {
        phase = .idle
        restRemaining = 0
        allDone = done
        PhaseAlerts.cancel()
        LiveActivityManager.shared.end()
        onUpdate?()
    }

    private func restEnded() {
        restRemaining = 0
        if guided, phase == .rest, cursor != nil { enterGetReady(seconds: 5) } else { LiveActivityManager.shared.end() }
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                if !self.tick() { return }
            }
        }
    }

    /// Advances date-based timers. Returns whether anything is still running.
    @discardableResult
    private func tick() -> Bool {
        if restRemaining > 0 {
            let left = max(0, Int(ceil(restEnd.timeIntervalSinceNow)))
            if left != restRemaining { restRemaining = left }
            if left == 0 { restEnded() }
        }
        let now = Date()
        if guided {
            if phase == .getReady, now >= phaseEnd {
                startWork()
            } else if phase == .work, now >= phaseEnd, !timeUp {
                timeUp = true
                timeUpTrigger += 1
                if autoComplete { completeWork() }
            }
        }
        return restRemaining > 0 || (guided && (phase == .getReady || phase == .work))
    }

    private func updateActivity() {
        onUpdate?()
        let (name, end, headline): (String, Date, String)
        switch phase {
        case .getReady:
            (name, end, headline) = ("ready", phaseEnd, currentExercise.map { "Preparati: \($0.name)" } ?? title)
        case .work:
            let reps = currentSet?.reps ?? 0
            let ex = currentExercise
            (name, end, headline) = ("work", phaseEnd, "\(ex?.name ?? title) · serie \(currentSetNumber)/\(ex?.sets.count ?? 0) · \(reps) rip")
        default:
            (name, end, headline) = ("rest", restEnd, cursor == nil ? title : upcomingDescription)
        }
        LiveActivityManager.shared.startOrUpdate(
            workout: title, phase: name, headline: headline, endDate: end, done: completedSets, total: totalSets
        )
    }

    /// Saves completed sets as a WorkoutLog. Returns false when nothing was completed.
    @discardableResult
    func save(to context: ModelContext) -> Bool {
        stopGuided()
        restRemaining = 0
        LiveActivityManager.shared.end()
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
