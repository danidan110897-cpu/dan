import Foundation
import UIKit

/// Minimal Claude Messages API client for structured (JSON schema) answers, with optional images.
/// The key comes from the Keychain (entered by the user in Settings) and requests go straight from the phone to Anthropic.
enum ClaudeClient {
    static let model = "claude-opus-5-5"

    static var hasKey: Bool { !(KeychainStore.get(ClaudeGenerator.keychainAccount) ?? "").isEmpty }

    static func textBlock(_ text: String) -> [String: Any] { ["type": "text", "text": text] }

    static func imageBlock(jpeg: Data) -> [String: Any] {
        ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]]
    }

    static func json(system: String, content: [[String: Any]], schema: [String: Any], maxTokens: Int = 2048) async throws -> [String: Any] {
        guard let key = KeychainStore.get(ClaudeGenerator.keychainAccount), !key.isEmpty else {
            throw GeneratorError.unavailable("Inserisci la tua chiave API di Anthropic in Impostazioni.")
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": content]],
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
            throw GeneratorError.badResponse("Claude non ha potuto analizzare questa richiesta.")
        }
        guard let blocks = json["content"] as? [[String: Any]],
              let text = blocks.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String,
              let payload = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw GeneratorError.badResponse("Risposta di Claude non leggibile.")
        }
        return obj
    }
}
