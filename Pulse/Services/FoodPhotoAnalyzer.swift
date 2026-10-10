import Foundation

/// One food recognised in a meal photo, with portion and nutrition per 100 g.
struct PhotoFoodItem: Identifiable {
    let id = UUID()
    var name: String
    var usdaQuery: String
    var grams: Double
    var confidence: String
    var aiKcal100: Double
    var aiProtein100: Double
    var aiCarbs100: Double
    var aiFat100: Double
}

struct PhotoMealResult {
    var items: [PhotoFoodItem]
    var note: String
}

/// Meal photo -> list of foods with estimated grams. Nutrition values are then looked up in USDA and checked against the AI estimate.
enum FoodPhotoAnalyzer {
    private static let system = """
    Sei un nutrizionista prudente che analizza la foto di un pasto.
    Regole:
    - Elenca ogni alimento visibile come voce separata. Non inventare alimenti che non si vedono.
    - Stima il peso in grammi di ciò che è nel piatto (cotto o crudo, come appare). Usa oggetti di riferimento (piatto, forchetta, mano, bicchiere) per valutare la scala.
    - Aggiungi come voci separate condimenti probabili e visibili (olio, burro, salse) solo se evidenti.
    - Per ogni voce dai valori per 100 g tipici dell'alimento come servito (kcal, proteine, carboidrati, grassi).
    - usdaQuery è una ricerca in inglese, semplice e generica (es. "chicken breast cooked", "white rice cooked", "olive oil").
    - confidence è low, medium o high a seconda di quanto sei sicuro di riconoscimento e porzione.
    - Se la foto non mostra cibo, restituisci items vuoto e spiega in note.
    - Nelle note, in italiano, segnala cosa renderebbe la stima più precisa (angolo dall'alto, un riferimento di scala, ingredienti nascosti).
    """

    private static var schema: [String: Any] {
        [
            "type": "object", "additionalProperties": false,
            "required": ["items", "note"],
            "properties": [
                "note": ["type": "string"],
                "items": [
                    "type": "array",
                    "items": [
                        "type": "object", "additionalProperties": false,
                        "required": ["name", "usdaQuery", "grams", "confidence", "kcal100", "protein100", "carbs100", "fat100"],
                        "properties": [
                            "name": ["type": "string"],
                            "usdaQuery": ["type": "string"],
                            "grams": ["type": "number"],
                            "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
                            "kcal100": ["type": "number"],
                            "protein100": ["type": "number"],
                            "carbs100": ["type": "number"],
                            "fat100": ["type": "number"],
                        ],
                    ],
                ],
            ],
        ]
    }

    static func analyze(jpeg: Data, hint: String) async throws -> PhotoMealResult {
        var text = "Analizza questo pasto."
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { text += " Informazioni dell'utente (fidati di queste): \(trimmed)" }
        let obj = try await ClaudeClient.json(
            system: system,
            content: [ClaudeClient.imageBlock(jpeg: jpeg), ClaudeClient.textBlock(text)],
            schema: schema,
            maxTokens: 2048
        )
        let items = (obj["items"] as? [[String: Any]] ?? []).compactMap { d -> PhotoFoodItem? in
            guard let name = d["name"] as? String, let grams = d["grams"] as? Double, grams > 0, grams < 3000 else { return nil }
            return PhotoFoodItem(
                name: name,
                usdaQuery: (d["usdaQuery"] as? String) ?? name,
                grams: grams.rounded(),
                confidence: (d["confidence"] as? String) ?? "low",
                aiKcal100: (d["kcal100"] as? Double) ?? 0,
                aiProtein100: (d["protein100"] as? Double) ?? 0,
                aiCarbs100: (d["carbs100"] as? Double) ?? 0,
                aiFat100: (d["fat100"] as? Double) ?? 0
            )
        }
        return PhotoMealResult(items: items, note: (obj["note"] as? String) ?? "")
    }

    /// Picks USDA values when they agree with the AI estimate (within 40% on calories); otherwise keeps the AI estimate,
    /// because a mismatch usually means the search found a different food (raw vs cooked, dried vs fresh).
    static func resolve(_ item: PhotoFoodItem, usdaKey: String) async -> ResolvedFood {
        let ai = ResolvedFood(source: "Stima AI", kcal100: item.aiKcal100, protein100: item.aiProtein100,
                              carbs100: item.aiCarbs100, fat100: item.aiFat100, matchedName: nil)
        let results = await FoodAPI.search(item.usdaQuery, usdaKey: usdaKey)
        guard let usda = results.first(where: { $0.source == "USDA" }) else { return ai }
        guard item.aiKcal100 > 0 else {
            return ResolvedFood(source: "USDA", kcal100: usda.kcal100, protein100: usda.protein100,
                                carbs100: usda.carbs100, fat100: usda.fat100, matchedName: usda.name)
        }
        let ratio = usda.kcal100 / item.aiKcal100
        if ratio > 0.6 && ratio < 1.4 {
            return ResolvedFood(source: "USDA", kcal100: usda.kcal100, protein100: usda.protein100,
                                carbs100: usda.carbs100, fat100: usda.fat100, matchedName: usda.name)
        }
        return ai
    }
}

struct ResolvedFood {
    let source: String
    let kcal100: Double
    let protein100: Double
    let carbs100: Double
    let fat100: Double
    let matchedName: String?
}
