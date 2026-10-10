import Foundation

/// Google Gemini (free tier with an AI Studio key). Used by ClaudeClient when the user has no Anthropic key,
/// so every photo and text feature works without paying. Answers are requested as JSON matching the same schemas.
enum GeminiClient {
    static let keychainAccount = "gemini-api-key"
    /// Tried in order: Google retires models for new keys from time to time, so the app falls through to the next name.
    static let models = ["gemini-3.8-flash", "gemini-flash-latest", "gemini-2.5-flash"]

    /// Key baked into the build from Config/Secrets.xcconfig (never committed). Empty when the build has none.
    static var bundledKey: String {
        let value = ((Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty, an unexpanded build variable or the example placeholder all mean "no key in this build".
        if value.isEmpty || value.hasPrefix("$(") || value.contains("PASTE_YOUR_KEY") { return "" }
        return value
    }

    /// A key typed in Settings wins; otherwise the one built into the app.
    static var activeKey: String {
        let typed = KeychainStore.get(keychainAccount) ?? ""
        return typed.isEmpty ? bundledKey : typed
    }

    static var hasKey: Bool { !activeKey.isEmpty }

    static func json(system: String, content: [[String: Any]], schema: [String: Any]) async throws -> [String: Any] {
        let key = activeKey
        guard !key.isEmpty else {
            throw GeneratorError.unavailable("Inserisci la tua chiave gratuita di Google (Gemini) in Impostazioni.")
        }
        var parts: [[String: Any]] = []
        for block in content {
            switch block["type"] as? String {
            case "text":
                if let text = block["text"] as? String { parts.append(["text": text]) }
            case "image":
                if let source = block["source"] as? [String: Any], let data = source["data"] as? String {
                    parts.append(["inlineData": ["mimeType": (source["media_type"] as? String) ?? "image/jpeg", "data": data]])
                }
            default: break
            }
        }
        let schemaText = (try? JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        parts.append(["text": "Rispondi SOLO con un oggetto JSON valido che rispetta questo JSON Schema, senza testo aggiuntivo:\n\(schemaText)"])

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["responseMimeType": "application/json", "temperature": 0.4],
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: body)
        var lastError = "Nessun modello Gemini disponibile."
        var json: [String: Any] = [:]
        var succeeded = false
        for model in models {
            var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!)
            req.httpMethod = "POST"
            req.timeoutInterval = 60
            req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = payloadData

            let (data, response) = try await URLSession.shared.data(for: req)
            json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) { succeeded = true; break }
            let message = ((json["error"] as? [String: Any])?["message"] as? String) ?? "Errore \(status)"
            if status == 429 { throw GeneratorError.badResponse("Hai finito le richieste gratuite di Gemini per ora. Riprova più tardi.") }
            lastError = message
            // Only a retired or unknown model is worth trying the next name for.
            let modelProblem = status == 404 || message.contains("no longer available") || message.contains("not found")
            if !modelProblem { throw GeneratorError.badResponse("Gemini ha risposto: \(message)") }
        }
        guard succeeded else { throw GeneratorError.badResponse("Gemini ha risposto: \(lastError)") }
        guard let candidate = (json["candidates"] as? [[String: Any]])?.first,
              let responseParts = (candidate["content"] as? [String: Any])?["parts"] as? [[String: Any]],
              let text = responseParts.compactMap({ $0["text"] as? String }).first,
              let payload = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw GeneratorError.badResponse("Gemini non ha potuto analizzare questa richiesta (o la risposta non è leggibile). Riprova con un'altra foto.")
        }
        return obj
    }
}
