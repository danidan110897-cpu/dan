import Foundation

/// "Ho mangiato pasta al pomodoro e due uova" -> estimated calories and macros for the whole portion, from the cloud AI.
enum FoodTextAnalyzer {
    struct Item: Identifiable {
        let id = UUID()
        var name: String
        var grams: Double
        var kcal: Double
        var protein: Double
        var carbs: Double
        var fat: Double
    }

    struct Result {
        var items: [Item]
        var note: String
        var kcal: Double { items.reduce(0) { $0 + $1.kcal } }
        var protein: Double { items.reduce(0) { $0 + $1.protein } }
        var carbs: Double { items.reduce(0) { $0 + $1.carbs } }
        var fat: Double { items.reduce(0) { $0 + $1.fat } }
    }

    private static let system = """
    Sei un nutrizionista prudente. L'utente descrive a parole cosa ha mangiato; devi stimare calorie e macronutrienti.
    Regole:
    - Elenca ogni alimento citato come voce separata. Non inventare alimenti che non sono nel testo.
    - Se la quantità manca, usa una porzione tipica italiana e dillo nelle note. Se c'è (es. "2 uova", "150 g di riso", "un cucchiaio d'olio"), usala.
    - grams è il peso stimato della porzione. kcal, protein, carbs e fat sono i TOTALI per quella porzione (non per 100 g), con grassi e carboidrati coerenti con le kcal.
    - Considera condimenti e cotture se citati (olio, burro, fritto).
    - Se il testo non parla di cibo, restituisci items vuoto e spiega nelle note.
    - Nelle note, in italiano e in una frase breve, di' cosa hai assunto per le quantità.
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
                        "required": ["name", "grams", "kcal", "protein", "carbs", "fat"],
                        "properties": [
                            "name": ["type": "string"],
                            "grams": ["type": "number"],
                            "kcal": ["type": "number"],
                            "protein": ["type": "number"],
                            "carbs": ["type": "number"],
                            "fat": ["type": "number"],
                        ],
                    ],
                ],
            ],
        ]
    }

    private static func number(_ v: Any?) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    static func analyze(_ text: String) async throws -> Result {
        let obj = try await ClaudeClient.json(
            system: system,
            content: [ClaudeClient.textBlock("Ho mangiato: \(text)")],
            schema: schema,
            maxTokens: 1024
        )
        let items = (obj["items"] as? [[String: Any]] ?? []).compactMap { d -> Item? in
            guard let name = d["name"] as? String, !name.isEmpty else { return nil }
            let protein = max(number(d["protein"]) ?? 0, 0)
            let carbs = max(number(d["carbs"]) ?? 0, 0)
            let fat = max(number(d["fat"]) ?? 0, 0)
            var kcal = max(number(d["kcal"]) ?? 0, 0)
            if kcal == 0 { kcal = protein * 4 + carbs * 4 + fat * 9 }
            // Anything beyond this is a mistake in the answer, not a meal.
            guard kcal < 5000, protein < 400, carbs < 800, fat < 400 else { return nil }
            return Item(name: name, grams: max(number(d["grams"]) ?? 0, 0), kcal: kcal, protein: protein, carbs: carbs, fat: fat)
        }
        return Result(items: items, note: (obj["note"] as? String) ?? "")
    }
}
