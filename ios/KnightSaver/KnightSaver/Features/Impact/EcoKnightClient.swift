import Foundation
import Security
import UIKit

// MARK: - What EcoKnight works with

struct EcoItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    /// "high", "medium" or "low" from the photo read. Students confirm every item.
    var confidence: String

    private enum CodingKeys: String, CodingKey { case name, quantity, confidence }

    init(name: String, quantity: Int, confidence: String = "high") {
        self.name = name
        self.quantity = quantity
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Item"
        quantity = max(1, (try? container.decode(Int.self, forKey: .quantity)) ?? 1)
        confidence = (try? container.decode(String.self, forKey: .confidence)) ?? "medium"
    }
}

struct EcoKitchen: Hashable {
    var microwave = true
    var miniFridge = true
    var kettle = false
    var stove = false

    var summary: String {
        var tools: [String] = []
        if microwave { tools.append("microwave") }
        if miniFridge { tools.append("mini-fridge") }
        if kettle { tools.append("electric kettle") }
        if stove { tools.append("stove") }
        return tools.isEmpty ? "no appliances" : tools.joined(separator: ", ")
    }
}

struct EcoPlan: Codable, Hashable {
    struct UseFirst: Codable, Hashable { var item: String; var why: String }
    struct Meal: Codable, Hashable, Identifiable {
        var title: String
        var minutes: Int?
        var uses: [String]?
        var steps: [String]
        var id: String { title }
    }
    struct Storage: Codable, Hashable { var item: String; var tip: String }

    var useFirst: [UseFirst]
    var meals: [Meal]
    var storage: [Storage]
    var share: String?
    var impact: String?
}

struct EcoIdentification: Codable {
    var items: [EcoItem]
    var note: String?
}

// MARK: - AI Messages API client

enum EcoKnightError: LocalizedError {
    case noKey
    case http(Int, String)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .noKey: return "Add an AI API key to use live AI."
        case .http(let code, let message): return "AI API error \(code): \(message)"
        case .unreadable: return "EcoKnight couldn't read the answer."
        }
    }
}

/// Talks to the live AI provider for EcoKnight. The API key lives only in this device's Keychain
/// (never in the repo). Without a key, or when a call fails, the views fall back to
/// `EcoKnightOffline` so the demo never breaks.
struct EcoKnightClient {
    static let model = "claude-haiku-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static var hasKey: Bool { APIKeyStore.load() != nil }

    /// Guardrails from student.md: suggestions only for confirmed items, no guarantees.
    static let rules = """
    You are EcoKnight, the food-rescue assistant inside KnightSaver, a UCF app where students pick up \
    surplus food from campus businesses in Surprise Bags.
    Rules:
    - Never guarantee what an item is from a photo. Say when you are unsure.
    - Never guarantee ingredients, allergens, freshness, expiration or food safety. Tell students to check \
    the business's labels when it matters.
    - Never invent statistics. Use only the impact numbers the app gives you, and call them estimates.
    - Suggest only uses for the items the student confirmed, plus basic pantry staples (salt, pepper, oil, \
    butter, sugar, water).
    - Respect the student's kitchen: dorm rooms often have only a microwave and a mini-fridge.
    - Be brief, friendly and practical. No emojis.
    """

    func identify(imageJPEG: Data?, note: String) async throws -> EcoIdentification {
        let prompt = """
        A student just picked up a KnightSaver Surprise Bag. \
        \(imageJPEG == nil ? "" : "The photo shows what was inside. ")\
        \(note.isEmpty ? "" : "The student says: \"\(note)\". ")
        List the food items you can identify with a quantity for each. Use simple everyday names \
        ("bagel", "chocolate chip cookie"). Mark confidence high, medium or low.
        Reply with only JSON: {"items":[{"name":"bagel","quantity":2,"confidence":"high"}],"note":"one short \
        sentence about anything unclear, or empty"}
        """
        let text = try await send(prompt: prompt, imageJPEG: imageJPEG, maxTokens: 600)
        return try Self.decode(EcoIdentification.self, from: text)
    }

    func plan(items: [EcoItem], kitchen: EcoKitchen, impactLine: String) async throws -> EcoPlan {
        let list = items.map { "\($0.quantity) × \($0.name)" }.joined(separator: ", ")
        let prompt = """
        Confirmed items from the student's Surprise Bag: \(list).
        Their kitchen: \(kitchen.summary).
        App impact numbers for this rescue (estimates, quote as given): \(impactLine).
        Make a short plan. Reply with only JSON:
        {"useFirst":[{"item":"","why":""}],
         "meals":[{"title":"","minutes":5,"uses":[""],"steps":["",""]}],
         "storage":[{"item":"","tip":""}],
         "share":"one sentence on sharing extra food responsibly, or empty",
         "impact":"one or two sentences explaining the estimated impact using only the numbers given"}
        Give 2-3 meals that work with their kitchen, at most 4 steps each, and general storage tips \
        (not safety guarantees).
        """
        let text = try await send(prompt: prompt, imageJPEG: nil, maxTokens: 1_200)
        return try Self.decode(EcoPlan.self, from: text)
    }

    /// One chat turn. `history` alternates user/assistant, oldest first, ending on the new question.
    func ask(history: [(role: String, text: String)], context: String) async throws -> String {
        let first = (role: "user", text: "Context from the app: \(context)\nAnswer my questions about using this food, storing it, food waste or carbon footprint. Keep answers under 120 words.")
        return try await send(turns: [first] + history, maxTokens: 500)
    }

    // MARK: Transport

    private func send(prompt: String, imageJPEG: Data?, maxTokens: Int) async throws -> String {
        var content: [[String: Any]] = []
        if let imageJPEG {
            content.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": imageJPEG.base64EncodedString()]
            ])
        }
        content.append(["type": "text", "text": prompt])
        return try await post(messages: [["role": "user", "content": content]], maxTokens: maxTokens)
    }

    private func send(turns: [(role: String, text: String)], maxTokens: Int) async throws -> String {
        // The API wants alternating roles; merge neighbours with the same role.
        var merged: [(role: String, text: String)] = []
        for turn in turns {
            if let last = merged.last, last.role == turn.role {
                merged[merged.count - 1].text += "\n\n" + turn.text
            } else {
                merged.append(turn)
            }
        }
        let messages: [[String: Any]] = merged.map { ["role": $0.role, "content": $0.text] }
        return try await post(messages: messages, maxTokens: maxTokens)
    }

    private func post(messages: [[String: Any]], maxTokens: Int) async throws -> String {
        guard let key = APIKeyStore.load() else { throw EcoKnightError.noKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": maxTokens,
            "system": Self.rules,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error.message ?? "Request failed"
            throw EcoKnightError.http(status, message)
        }
        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        let text = decoded.content.compactMap(\.text).joined()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EcoKnightError.unreadable }
        return text
    }

    /// Reads the JSON object out of a reply, tolerating a sentence or code fence around it.
    static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8) else { throw EcoKnightError.unreadable }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw EcoKnightError.unreadable
        }
    }

    /// Shrinks a photo before sending: longest side 1024 px, JPEG.
    static func preparedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1024 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    private struct MessagesResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private struct APIErrorBody: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}

// MARK: - Offline fallback (no key, no network)

enum EcoKnightOffline {
    static func identify(note: String) -> EcoIdentification {
        // "2 bagels, a croissant and 3 cookies" → items. Reuses the Kitchen parser.
        let parsed = SurplusAssistant.interpret(note).inventory
        let items = parsed.map { EcoItem(name: $0.name.lowercased(), quantity: $0.quantity, confidence: "high") }
        return EcoIdentification(
            items: items,
            note: items.isEmpty ? "Type what's in your bag, for example \"2 bagels and a cookie\"." : nil
        )
    }

    static func plan(items: [EcoItem], kitchen: EcoKitchen, impactLine: String) -> EcoPlan {
        let names = items.map { $0.name.lowercased() }
        let breads = names.filter { matches($0, ["bagel", "bread", "roll", "croissant", "muffin", "pastr", "biscuit", "scone"]) }
        let sweets = names.filter { matches($0, ["cookie", "brownie", "donut", "cake", "pastr"]) }
        let savory = names.filter { matches($0, ["sandwich", "wrap", "salad", "pizza", "burrito", "bowl"]) }

        var meals: [EcoPlan.Meal] = []
        if let bread = breads.first {
            meals.append(.init(
                title: kitchen.microwave ? "Warm \(bread) with butter" : "\(bread.capitalized) with whatever you have",
                minutes: 3,
                uses: [bread],
                steps: kitchen.microwave
                    ? ["Wrap the \(bread) in a damp paper towel.", "Microwave 15–20 seconds.", "Add butter or a spread."]
                    : ["Split the \(bread).", "Add a spread or fruit you already have."]
            ))
        }
        if let main = savory.first {
            meals.append(.init(
                title: "Tonight's \(main)",
                minutes: 2,
                uses: [main],
                steps: kitchen.miniFridge
                    ? ["Eat it first: it keeps the shortest.", "Chill anything you don't finish within 2 hours."]
                    : ["Eat it first: it keeps the shortest.", "Without a fridge, finish it today."]
            ))
        }
        if let sweet = sweets.first {
            meals.append(.init(
                title: "Study-break \(sweet)",
                minutes: 1,
                uses: [sweet],
                steps: ["Save one for later in a sealed bag.", "Share the rest with your floor."]
            ))
        }
        if meals.isEmpty {
            meals.append(.init(title: "Plate it up", minutes: 2, uses: names, steps: ["Eat the softest items first.", "Seal the rest and keep them cool."]))
        }

        let useFirst = items
            .sorted { rank($0.name) < rank($1.name) }
            .prefix(2)
            .map { EcoPlan.UseFirst(item: $0.name, why: rank($0.name) == 0 ? "Fillings and dressings spoil fastest." : "Baked goods dry out within a day or two.") }

        let storage = items.prefix(3).map { item in
            EcoPlan.Storage(
                item: item.name,
                tip: rank(item.name) == 0
                    ? (kitchen.miniFridge ? "Keep it in the mini-fridge and eat it within a day." : "Eat it today.")
                    : "Seal it in a bag at room temperature; it freezes well too."
            )
        }

        return EcoPlan(
            useFirst: Array(useFirst),
            meals: Array(meals.prefix(3)),
            storage: Array(storage),
            share: items.reduce(0) { $0 + $1.quantity } > 3 ? "More than you can finish? Share sealed items with friends the same day." : nil,
            impact: "This rescue: \(impactLine). These are estimates, not measurements."
        )
    }

    static func answer(_ question: String) -> String {
        let q = question.lowercased()
        if q.contains("freeze") {
            return "Most bread, bagels, muffins and cookies freeze well for a few weeks. Wrap them tightly and thaw at room temperature or in the microwave. Check the business's labels for anything with fillings."
        }
        if q.contains("carbon") || q.contains("co2") || q.contains("climate") {
            return "Food that's thrown away wastes everything it took to grow, cook and transport it, and it releases methane in landfills. Eating rescued food avoids part of that. KnightSaver shows your share as an estimate."
        }
        if q.contains("safe") || q.contains("allerg") || q.contains("expire") {
            return "EcoKnight can't confirm safety, allergens or expiration. Ask the business staff or check their labels, and when in doubt, leave it out."
        }
        return "Live AI isn't connected, so here's the short version: eat the items with fillings first, keep leftovers sealed and cool, and share what you can't finish the same day."
    }

    /// 0 = spoils fastest.
    private static func rank(_ name: String) -> Int {
        matches(name.lowercased(), ["sandwich", "wrap", "salad", "sushi", "yogurt", "fruit", "pizza", "bowl"]) ? 0 : 1
    }

    private static func matches(_ name: String, _ words: [String]) -> Bool {
        words.contains { word in name.contains(word) }
    }
}

// MARK: - Keychain

/// Stores the AI API key on this device only.
enum APIKeyStore {
    private static let service = "knightsaver.ecoknight"
    private static let account = "anthropic-api-key"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
