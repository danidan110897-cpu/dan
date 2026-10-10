import Foundation

struct BodyFatEstimate {
    let low: Double
    let high: Double
    let confidence: String
    let notes: [String]
}

struct WeeklyNarrative {
    let summary: String
    let observations: [String]
    let suggestions: [String]
    let caution: String
}

/// AI analysis of progress photos. Photos are sent to Anthropic only when the user explicitly asks, with their own API key.
enum PhotoAnalyzer {
    private static let estimateSystem = """
    Sei un assistente che stima in modo prudente la percentuale di grasso corporeo di una persona adulta da una foto.
    Regole:
    - Dai sempre un intervallo (bodyFatLow e bodyFatHigh, ampio almeno 4 punti percentuali), mai un numero singolo.
    - Se la foto non è adatta (busto non visibile, luce scarsa, abiti larghi, angolazione sbagliata) o la persona sembra minorenne, imposta usable=false e spiega brevemente in reason; in quel caso bodyFatLow e bodyFatHigh valgono 0.
    - confidence deve essere low, medium o high; usa high solo con foto frontale nitida e ben illuminata.
    - Le note riguardano solo la qualità della foto e i limiti della stima, in italiano e con tono neutro.
    - Non giudicare l'aspetto estetico, non dare consigli dietetici restrittivi e non fare diagnosi.
    """

    private static let narrativeSystem = """
    Sei un assistente che riassume in modo prudente e incoraggiante l'andamento settimanale di una persona che si allena.
    Regole:
    - Basati prima di tutto sui dati misurati (allenamenti, volume, cibo, peso, vita). Le foto servono solo come contesto.
    - Differenze di luce, posa, pompa muscolare e abbigliamento rendono i confronti tra foto poco affidabili: dillo se serve e non affermare perdita di grasso o aumento di massa solo dalle foto.
    - Tono neutro e rispettoso, in italiano, senza giudizi sull'aspetto e senza spingere a diete o allenamenti estremi.
    - Suggerimenti concreti e piccoli (massimo 3). Se i dati sono scarsi, dillo.
    - Non dare consigli medici.
    """

    private static var estimateSchema: [String: Any] {
        [
            "type": "object", "additionalProperties": false,
            "required": ["usable", "reason", "bodyFatLow", "bodyFatHigh", "confidence", "notes"],
            "properties": [
                "usable": ["type": "boolean"],
                "reason": ["type": "string"],
                "bodyFatLow": ["type": "number"],
                "bodyFatHigh": ["type": "number"],
                "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
                "notes": ["type": "array", "items": ["type": "string"]],
            ],
        ]
    }

    private static var narrativeSchema: [String: Any] {
        [
            "type": "object", "additionalProperties": false,
            "required": ["summary", "observations", "suggestions", "caution"],
            "properties": [
                "summary": ["type": "string"],
                "observations": ["type": "array", "items": ["type": "string"]],
                "suggestions": ["type": "array", "items": ["type": "string"]],
                "caution": ["type": "string"],
            ],
        ]
    }

    static func estimate(photoFile: String, profile: BodyProfile) async throws -> BodyFatEstimate {
        guard profile.age >= 18 else {
            throw GeneratorError.unavailable("La stima dalla foto è disponibile solo per maggiorenni.")
        }
        guard let jpeg = PhotoStorage.jpegData(photoFile, maxSide: 1024) else {
            throw GeneratorError.badResponse("Foto non leggibile.")
        }
        let context = "Persona: \(profile.sex == .male ? "uomo" : "donna"), \(profile.age) anni, \(Int(profile.heightCm)) cm, \(profile.weightKg) kg. Stima la percentuale di grasso corporeo dalla foto."
        let obj = try await ClaudeClient.json(
            system: estimateSystem,
            content: [ClaudeClient.imageBlock(jpeg: jpeg), ClaudeClient.textBlock(context)],
            schema: estimateSchema
        )
        guard (obj["usable"] as? Bool) == true else {
            throw GeneratorError.badResponse((obj["reason"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "La foto non è adatta alla stima.")
        }
        let low = (obj["bodyFatLow"] as? Double) ?? 0
        let high = (obj["bodyFatHigh"] as? Double) ?? 0
        guard low > 0, high >= low, high < 70 else {
            throw GeneratorError.badResponse("Stima non attendibile: riprova con una foto più chiara.")
        }
        return BodyFatEstimate(low: low, high: high, confidence: (obj["confidence"] as? String) ?? "low",
                               notes: (obj["notes"] as? [String]) ?? [])
    }

    static func weeklyNarrative(statsJSON: String, beforeFile: String?, afterFile: String?) async throws -> WeeklyNarrative {
        var content: [[String: Any]] = []
        var intro = "Dati della settimana (JSON):\n\(statsJSON)"
        if let beforeFile, let afterFile,
           let before = PhotoStorage.jpegData(beforeFile, maxSide: 900),
           let after = PhotoStorage.jpegData(afterFile, maxSide: 900) {
            content.append(ClaudeClient.textBlock("Foto precedente:"))
            content.append(ClaudeClient.imageBlock(jpeg: before))
            content.append(ClaudeClient.textBlock("Foto più recente:"))
            content.append(ClaudeClient.imageBlock(jpeg: after))
            intro += "\nConfronta anche le due foto, con la massima cautela."
        }
        content.append(ClaudeClient.textBlock(intro))
        let obj = try await ClaudeClient.json(system: narrativeSystem, content: content, schema: narrativeSchema)
        return WeeklyNarrative(
            summary: (obj["summary"] as? String) ?? "",
            observations: (obj["observations"] as? [String]) ?? [],
            suggestions: (obj["suggestions"] as? [String]) ?? [],
            caution: (obj["caution"] as? String) ?? ""
        )
    }
}
