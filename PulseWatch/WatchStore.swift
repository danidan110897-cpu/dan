import SwiftUI
import Observation
import WatchKit

@MainActor @Observable
final class WatchStore {
    var snapshot: WorkoutSnapshot?
    var restRemaining = 0
    var restTotal = 90
    var completionTick = 0
    private var restTask: Task<Void, Never>?
    private var alertTask: Task<Void, Never>?
    private var lastPhase: String?

    var current: (exercise: WorkoutSnapshot.Exercise, set: WorkoutSnapshot.WorkoutSet, index: Int)? {
        guard let snapshot else { return nil }
        for ex in snapshot.exercises {
            if let i = ex.sets.firstIndex(where: { !$0.isDone }) { return (ex, ex.sets[i], i + 1) }
        }
        return nil
    }

    var doneCount: Int { snapshot?.exercises.flatMap(\.sets).filter(\.isDone).count ?? 0 }
    var totalCount: Int { snapshot?.exercises.flatMap(\.sets).count ?? 0 }
    var isFinished: Bool { snapshot != nil && current == nil }

    func start() {
        let link = Connectivity.shared
        link.onSnapshot = { [weak self] new in
            guard let self else { return }
            let before = self.doneCount
            withAnimation(.snappy) { self.snapshot = new }
            self.followGuided(new.guided)
            // A set finished on the phone also starts the rest here (the guided flow mirrors its own countdown).
            if new.guided == nil, self.doneCount > before { self.startRest(seconds: new.restSeconds) }
        }
        link.activate()
    }

    func complete(_ ex: WorkoutSnapshot.Exercise, _ set: WorkoutSnapshot.WorkoutSet) {
        guard var snap = snapshot,
              let e = snap.exercises.firstIndex(where: { $0.id == ex.id }),
              let s = snap.exercises[e].sets.firstIndex(where: { $0.id == set.id }) else { return }
        snap.exercises[e].sets[s].isDone = true
        withAnimation(.snappy) { snapshot = snap }
        completionTick += 1
        startRest(seconds: snap.restSeconds)
        Connectivity.shared.send(toggle: SetToggle(exerciseID: ex.id, setID: set.id, isDone: true))
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

    func skipRest() {
        restTask?.cancel()
        restRemaining = 0
    }

    /// Taps the wrist on every phase change and when a set's estimated time is over, so the screen lights up with the next step.
    private func followGuided(_ g: GuidedState?) {
        alertTask?.cancel()
        guard let g else { lastPhase = nil; return }
        if g.phase != lastPhase {
            switch g.phase {
            case "ready": WKInterfaceDevice.current().play(.directionUp)
            case "work": WKInterfaceDevice.current().play(.start)
            default: WKInterfaceDevice.current().play(.success)
            }
            lastPhase = g.phase
        }
        if g.phase == "work" {
            let end = g.endDate
            alertTask = Task {
                let wait = end.timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if !Task.isCancelled { WKInterfaceDevice.current().play(.notification) }
            }
        }
    }

    func primaryAction() {
        WKInterfaceDevice.current().play(.click)
        Connectivity.shared.sendAction()
    }
}
