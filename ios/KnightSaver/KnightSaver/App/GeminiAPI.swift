import Foundation

/// Google's Gemini API, called straight from the phone for EcoKnight AI and the Kitchen voice
/// assistant. The key comes from `App/Secrets.xcconfig` (gitignored) through Info.plist.
/// Without a key, callers use their on-phone fallbacks.
enum GeminiAPI {
    /// Fast enough for staff waiting at the counter. The backup answers when the first is
    /// overloaded or rate-limited.
    static let models = ["gemini-3.5-flash-lite", "gemini-3.6-flash"]
    private static let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!

    enum Failure: LocalizedError {
        case notConfigured
        case blocked
        case server(Int, String)
        case unreadable

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Add a Gemini API key in Secrets.xcconfig to use live AI."
            case .blocked: return "Gemini declined to answer that one."
            case .server(let code, let message): return "Gemini error \(code): \(message)"
            case .unreadable: return "Gemini's answer couldn't be read."
            }
        }
    }

    static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unset build setting can arrive empty or as the literal "$(GEMINI_API_KEY)".
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }

    static var isConfigured: Bool { apiKey != nil }

    /// One `generateContent` call. `body` holds the request fields (contents, systemInstruction,
    /// tools, generationConfig). Returns the first candidate's content, unchanged so it can go
    /// back into the history with its thought signatures.
    static func generate(_ body: [String: Any]) async throws -> [String: Any] {
        guard let apiKey else { throw Failure.notConfigured }
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        var lastError: Error = Failure.unreadable
        for model in models {
            do {
                return try await generate(data, model: model, apiKey: apiKey)
            } catch let Failure.server(code, message) where code == 429 || code >= 500 {
                lastError = Failure.server(code, message)
            } catch let error as URLError where error.code == .timedOut {
                lastError = error
            }
        }
        throw lastError
    }

    private static func generate(_ body: Data, model: String, apiKey: String) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL.appending(path: "\(model):generateContent"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 200 else {
            let message = (object?["error"] as? [String: Any])?["message"] as? String ?? "Request failed"
            throw Failure.server(status, message)
        }
        if (object?["promptFeedback"] as? [String: Any])?["blockReason"] != nil { throw Failure.blocked }
        guard let candidate = (object?["candidates"] as? [[String: Any]])?.first else { throw Failure.unreadable }
        let finish = candidate["finishReason"] as? String ?? ""
        if ["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII"].contains(finish) { throw Failure.blocked }
        guard var content = candidate["content"] as? [String: Any] else { throw Failure.unreadable }
        if content["role"] == nil { content["role"] = "model" }
        return content
    }

    /// The visible text of a model content, without thought parts.
    static func text(of content: [String: Any]) -> String {
        (content["parts"] as? [[String: Any]] ?? [])
            .filter { $0["thought"] as? Bool != true }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
