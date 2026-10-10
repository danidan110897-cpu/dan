import Foundation

/// Creates routines with the Claude API (Messages endpoint, structured JSON output).
/// The API key is entered by the user in Settings and kept in the Keychain on their own device.
struct ClaudeGenerator: WorkoutGenerator {
    static let keychainAccount = "anthropic-api-key"
    static let model = "claude-opus-5-5"

    func generate(_ request: GenerationRequest, library: [LibraryEntry]) async throws -> GeneratedPlan {
        guard let key = KeychainStore.get(Self.keychainAccount), !key.isEmpty else {
            throw GeneratorError.unavailable("Inserisci la tua chiave API di Anthropic in Impostazioni.")
        }
        let usable = library.filter { PlanValidator.allowed($0, request) }

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["routines", "rationale"],
            "properties": [
                "rationale": ["type": "string"],
                "routines": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["name", "exercises"],
                        "properties": [
                            "name": ["type": "string"],
                            "exercises": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "additionalProperties": false,
                                    "required": ["key", "sets", "reps", "note"],
                                    "properties": [
                                        "key": ["type": "string", "enum": usable.map(\.key)],
                                        "sets": ["type": "integer"],
                                        "reps": ["type": "integer"],
                                        "note": ["type": "string"],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 4096,
            "system": GeneratorPrompt.system,
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": GeneratorPrompt.user(request, library: usable)]],
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = ((json["error"] as? [String: Any])?["message"] as? String) ?? "Errore \(status)"
            throw GeneratorError.badResponse("Claude ha risposto: \(message)")
        }
        if (json["stop_reason"] as? String) == "refusal" {
            throw GeneratorError.badResponse("Claude ha rifiutato la richiesta. Riformulala senza dettagli sensibili.")
        }
        guard let blocks = json["content"] as? [[String: Any]],
              let text = blocks.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String,
              let payload = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw GeneratorError.badResponse("Risposta di Claude non leggibile.")
        }

        let routines = (obj["routines"] as? [[String: Any]] ?? []).map { r in
            GeneratedRoutine(
                name: (r["name"] as? String) ?? "Routine",
                exercises: (r["exercises"] as? [[String: Any]] ?? []).map { e in
                    GeneratedExercise(key: (e["key"] as? String) ?? "", sets: (e["sets"] as? Int) ?? 3,
                                      reps: (e["reps"] as? Int) ?? 10, note: (e["note"] as? String) ?? "")
                }
            )
        }
        return GeneratedPlan(routines: routines, rationale: (obj["rationale"] as? String) ?? "")
    }
}
