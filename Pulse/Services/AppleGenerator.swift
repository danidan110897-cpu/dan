import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device generation with Apple Intelligence. Needs iOS 26 and a supported iPhone; otherwise it reports itself unavailable.
struct AppleGenerator: WorkoutGenerator {
    static var isAvailable: Bool { AIEngine.appleStatus.isAvailable }

    func generate(_ request: GenerationRequest, library: [LibraryEntry]) async throws -> GeneratedPlan {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw GeneratorError.unavailable("Apple Intelligence non è disponibile su questo iPhone o non è attivata.")
            }
            let usable = library.filter { PlanValidator.allowed($0, request) }
            let session = LanguageModelSession(instructions: GeneratorPrompt.system)
            let result = try await session.respond(to: GeneratorPrompt.user(request, library: usable), generating: AIPlan.self)
            let plan = result.content
            return GeneratedPlan(
                routines: plan.routines.map { r in
                    GeneratedRoutine(name: r.name, exercises: r.exercises.map {
                        GeneratedExercise(key: $0.key, sets: $0.sets, reps: $0.reps, note: $0.note)
                    })
                },
                rationale: plan.rationale
            )
        }
        #endif
        throw GeneratorError.unavailable("Apple Intelligence richiede iOS 26 e un iPhone compatibile.")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct AIExercise {
    @Guide(description: "Chiave esatta dell'esercizio presa dalla libreria")
    var key: String
    @Guide(description: "Numero di serie, da 2 a 5")
    var sets: Int
    @Guide(description: "Ripetizioni per serie, da 3 a 20")
    var reps: Int
    @Guide(description: "Breve nota di esecuzione, può essere vuota")
    var note: String
}

@available(iOS 26.0, *)
@Generable
private struct AIRoutine {
    @Guide(description: "Nome della routine, ad esempio Giorno 1 · Push")
    var name: String
    var exercises: [AIExercise]
}

@available(iOS 26.0, *)
@Generable
private struct AIPlan {
    var routines: [AIRoutine]
    @Guide(description: "Spiegazione in italiano di 3-5 frasi sulle scelte fatte")
    var rationale: String
}
#endif
