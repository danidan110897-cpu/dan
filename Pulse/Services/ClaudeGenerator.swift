import Foundation

/// Creates routines with the Claude API (Messages endpoint, structured JSON output).
/// The API key is entered by the user in Settings and kept in the Keychain on their own device.
struct ClaudeGenerator: WorkoutGenerator {
    static let keychainAccount = "anthropic-api-key"
    static let model = "claude-opus-5-5"

    func generate(_ request: GenerationRequest, library: [LibraryEntry]) async throws -> GeneratedPlan {
        guard ClaudeClient.hasKey else {
            throw GeneratorError.unavailable("Inserisci una chiave API in Impostazioni (quella gratuita di Google va bene).")
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

        let obj = try await ClaudeClient.json(
            system: GeneratorPrompt.system,
            content: [ClaudeClient.textBlock(GeneratorPrompt.user(request, library: usable))],
            schema: schema,
            maxTokens: 4096
        )

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
