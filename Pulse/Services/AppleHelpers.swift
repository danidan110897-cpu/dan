import Foundation
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Text tasks on the on-device Apple model (iOS 26: the model reads and writes text only).
enum AppleHelpers {
    /// Weekly summary written from the numbers only (no photos: the on-device model can't read images on iOS 26).
    static func narrative(statsJSON: String) async throws -> WeeklyNarrative {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), AIEngine.appleStatus.isAvailable {
            let session = LanguageModelSession(instructions: """
            Sei un assistente che riassume in modo prudente e incoraggiante l'andamento settimanale di una persona che si allena.
            Basati solo sui numeri forniti, tono neutro e rispettoso, in italiano, al massimo 3 suggerimenti piccoli e concreti.
            Se i dati sono scarsi dillo. Non dare consigli medici e non spingere a diete o allenamenti estremi.
            """)
            let result = try await session.respond(to: "Dati della settimana (JSON):\n\(statsJSON)", generating: AINarrative.self)
            let n = result.content
            return WeeklyNarrative(summary: n.summary, observations: n.observations, suggestions: n.suggestions, caution: n.caution)
        }
        #endif
        throw GeneratorError.unavailable(AIEngine.appleStatus.label)
    }

    /// Turns image labels (from Vision) plus the user's note into foods with typical portions.
    static func foods(labels: [String], hint: String) async throws -> [PhotoFoodItem] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), AIEngine.appleStatus.isAvailable {
            let session = LanguageModelSession(instructions: """
            Aiuti a registrare un pasto. Ricevi etichette automatiche di una foto (possono essere imprecise) e una nota dell'utente.
            Scegli solo alimenti o piatti realmente commestibili tra le etichette, ignora oggetti e ambienti.
            Per ogni voce dai: nome in italiano, una ricerca in inglese semplice (usdaQuery), una porzione tipica in grammi
            (usa i grammi della nota dell'utente se presenti) e i valori per 100 g (kcal, proteine, carboidrati, grassi).
            Se nessuna etichetta è un alimento, restituisci una lista vuota.
            """)
            let prompt = "Etichette della foto: \(labels.joined(separator: ", ")).\nNota dell'utente: \(hint.isEmpty ? "nessuna" : hint)"
            let result = try await session.respond(to: prompt, generating: AIFoodList.self)
            return result.content.items.compactMap { f in
                guard f.grams > 0, f.grams < 2000 else { return nil }
                return PhotoFoodItem(name: f.name, usdaQuery: f.usdaQuery, grams: f.grams.rounded(), confidence: "low",
                                     aiKcal100: f.kcal100, aiProtein100: f.protein100, aiCarbs100: f.carbs100, aiFat100: f.fat100)
            }
        }
        #endif
        throw GeneratorError.unavailable(AIEngine.appleStatus.label)
    }

    /// On-device image classification (works on every iPhone, free, nothing leaves the phone).
    static func imageLabels(_ jpeg: Data) async -> [String] {
        await Task.detached(priority: .userInitiated) { () -> [String] in
            guard let cg = UIImage(data: jpeg)?.cgImage else { return [] }
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do { try handler.perform([request]) } catch { return [] }
            let observations = (request.results ?? []) as [VNClassificationObservation]
            return observations
                .filter { $0.confidence > 0.08 }
                .prefix(15)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
        }.value
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct AINarrative {
    @Guide(description: "Riepilogo di 2-3 frasi")
    var summary: String
    var observations: [String]
    @Guide(description: "Al massimo 3 suggerimenti")
    var suggestions: [String]
    @Guide(description: "Una frase di cautela sui limiti dei dati")
    var caution: String
}

@available(iOS 26.0, *)
@Generable
private struct AIFood {
    var name: String
    var usdaQuery: String
    @Guide(description: "Porzione in grammi")
    var grams: Double
    var kcal100: Double
    var protein100: Double
    var carbs100: Double
    var fat100: Double
}

@available(iOS 26.0, *)
@Generable
private struct AIFoodList {
    var items: [AIFood]
}
#endif
