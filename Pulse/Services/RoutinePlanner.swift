import Foundation
import SwiftData

/// Creates a validated routine plan with the chosen AI engine, falling back to the offline rules when allowed.
enum RoutinePlanner {
    struct Outcome {
        let plan: GeneratedPlan
        let used: AIEngine.Choice
        /// Set when the AI failed and the rules were used instead.
        let fallbackReason: String?
    }

    static func generate(_ request: GenerationRequest, library: [LibraryEntry], choice: AIEngine.Choice, allowFallback: Bool) async throws -> Outcome {
        func make(_ c: AIEngine.Choice) -> any WorkoutGenerator {
            switch c {
            case .apple: return AppleGenerator()
            case .claude: return ClaudeGenerator()
            case .local: return RuleBasedGenerator()
            }
        }
        do {
            let generator = make(choice)
            // An engine that never answers must not freeze the screen: give up and fall back to the rules.
            let raw = try await withTimeout(choice == .apple ? 30 : 90) { try await generator.generate(request, library: library) }
            return Outcome(plan: PlanValidator.validate(raw, request: request, library: library), used: choice, fallbackReason: nil)
        } catch {
            guard allowFallback, choice != .local else { throw error }
            let raw = try await RuleBasedGenerator().generate(request, library: library)
            return Outcome(plan: PlanValidator.validate(raw, request: request, library: library), used: .local,
                           fallbackReason: error.localizedDescription)
        }
    }

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func take() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    /// Returns the first of: the operation's result, or a timeout error. Does not wait for an operation that ignores cancellation.
    static func withTimeout<T>(_ seconds: Double, _ operation: @escaping () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            let work = Task {
                do {
                    let value = try await operation()
                    if once.take() { continuation.resume(returning: value) }
                } catch {
                    if once.take() { continuation.resume(throwing: error) }
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                if once.take() {
                    work.cancel()
                    continuation.resume(throwing: GeneratorError.unavailable("L'AI ci ha messo troppo tempo a rispondere."))
                }
            }
        }
    }

    /// Stores the plan as routines and returns the first one.
    @MainActor
    @discardableResult
    static func save(_ plan: GeneratedPlan, restSeconds: Int, exercises: [Exercise], context: ModelContext) -> Routine? {
        var first: Routine?
        let days = TrainingSchedule.defaultWeekdays(count: plan.routines.count)
        for (index, r) in plan.routines.enumerated() {
            let routine = Routine(name: r.name, restSeconds: restSeconds)
            if index < days.count { routine.weekdays = [days[index]] }
            context.insert(routine)
            for (i, g) in r.exercises.enumerated() {
                guard let ex = exercises.first(where: { $0.key == g.key }) else { continue }
                let item = RoutineItem(order: i, exercise: ex, sets: g.sets, reps: g.reps)
                item.note = g.note
                routine.items.append(item)
            }
            if first == nil { first = routine }
        }
        try? context.save()
        return first
    }
}
