import Foundation
import Security
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - What EcoKnight may read

/// The student's numbers as the Impact tab shows them. EcoKnight's tools read from this
/// snapshot on the phone, and only when Claude asks for them (and the student allows it).
struct EcoStats {
    let summary: StudentImpactSummary
    /// Newest first.
    let rescues: [StudentRescue]
    /// The league nickname, or nil when the student hasn't joined the league.
    let leagueNickname: String?

    var campusBagsThisWeek: Int {
        ImpactDemo.campusBase.bagsThisWeek + (summary.weeklyBags(weeks: 1).first ?? 0)
    }
}

// MARK: - Claude Messages API client

enum EcoKnightError: LocalizedError {
    case noKey
    case http(Int, String)
    case unreadable
    case refused

    var errorDescription: String? {
        switch self {
        case .noKey: return "Add a Claude API key to use live AI."
        case .http(let code, let message): return "Claude API error \(code): \(message)"
        case .unreadable: return "EcoKnight couldn't read the answer."
        case .refused: return "EcoKnight can't help with that one. Try asking another way."
        }
    }
}

/// Talks to Claude for EcoKnight AI: an environmental chat that can look up the student's own
/// rescue stats with tools. The API key lives only in this device's Keychain (never in the repo).
/// Without a key, or when a call fails, the view falls back to `EcoKnightOffline`.
struct EcoKnightClient {
    static let model = "claude-haiku-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    /// Upper bound on tool rounds in one answer, so a confused loop can't run forever.
    private static let maxToolRounds = 5

    static var hasKey: Bool { APIKeyStore.load() != nil }

    /// Guardrails from student.md: estimates stay estimates, no guarantees about food safety.
    static func rules(statsAccess: Bool) -> String {
        """
        You are EcoKnight, the environmental assistant inside KnightSaver, a UCF app where students \
        rescue surplus food from campus businesses in Surprise Bags. Help with food waste, climate and \
        sustainable habits on campus, and with the student's own rescue impact.
        Rules:
        - \(statsAccess
            ? "For questions about the student's own numbers, rescues, streak, league standing or campus totals, call the matching stats tool. Don't call the stats tools for general questions."
            : "The student has turned off stats access. If they ask about their own numbers, say they can turn on \"Let EcoKnight see my stats\" in EcoKnight.")
        - Quote the student's or campus numbers only from tool results. Food weights are weighed or \
        estimated as the tool says, and CO2e figures are always estimates. Say so.
        - Every number you give must come from a tool result. For general environmental numbers, call \
        get_environment_facts and quote it with its source. If the fact you'd need isn't there, explain \
        without numbers. Never name studies, organizations or sources that a tool didn't give you.
        - Don't claim UCF has a specific program, website, place or service unless a tool says so.
        - Never mention tool names to the student.
        - Never guarantee ingredients, allergens, freshness, expiration or food safety. Tell students to \
        check the business's labels when it matters.
        - When the student shares a photo of food, list what you think you see, say what you're unsure \
        of, and ask them to confirm before giving item-specific ideas.
        - Dorm rooms often have only a microwave and a mini-fridge.
        - Be brief, friendly and practical: under 150 words unless asked for more. Plain text; short \
        lists starting with "- " are fine. No headings, no emojis.
        """
    }

    // MARK: Tools

    private static let factsTool: [String: Any] = [
        "name": "get_environment_facts",
        "description": "A short list of verified, sourced facts about food waste and climate. Call this before giving any general environmental number or statistic, and quote only what it returns, with its source.",
        "input_schema": ["type": "object", "properties": [String: Any](), "additionalProperties": false]
    ]

    private static let statsTools: [[String: Any]] = [
        [
            "name": "get_my_impact",
            "description": "The student's own verified rescue totals: bags, food weight (weighed and estimated), estimated CO2e avoided, weekly streak, bags per week for the last 6 weeks, and Rescue League points. Call this when the student asks about their impact, progress, streak or points.",
            "input_schema": ["type": "object", "properties": [String: Any](), "additionalProperties": false]
        ],
        [
            "name": "get_my_rescues",
            "description": "The student's most recent staff-verified pickups, newest first: business, date, bags and food weight. Call this when the student asks what they rescued, where, or when, or wants ideas based on a past bag.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "limit": ["type": "integer", "description": "How many rescues to return, 1 to 20. Default 5."]
                ],
                "additionalProperties": false
            ]
        ],
        [
            "name": "get_campus_impact",
            "description": "UCF campus totals from KnightSaver: bags rescued this week against the weekly goal, all-time bags, food rescued and estimated CO2e avoided. Call this when the student asks how campus is doing.",
            "input_schema": ["type": "object", "properties": [String: Any](), "additionalProperties": false]
        ],
        [
            "name": "get_league_standing",
            "description": "The Campus Rescue League leaderboard (nicknames only) and the student's rank if they joined. One point per day with a verified pickup. Call this when the student asks about the league, their rank, or Knight of the Week.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "period": ["type": "string", "enum": ["week", "all_time"], "description": "This week or all time. Default week."]
                ],
                "additionalProperties": false
            ]
        ]
    ]

    /// Plain words for the "Looked at" line under an answer.
    static func label(forTool name: String) -> String {
        switch name {
        case "get_my_impact": return "your impact"
        case "get_my_rescues": return "your rescues"
        case "get_campus_impact": return "campus totals"
        case "get_league_standing": return "the league"
        case "get_environment_facts": return "EcoKnight's fact list"
        default: return name
        }
    }

    /// General environmental facts EcoKnight may quote, with their sources. Keep this list short
    /// and verified: it is the only place EcoKnight's general numbers come from.
    /// The team must check each line against its source before launch.
    static let environmentFacts: [String] = [
        "Food is the single largest category of material sent to US municipal landfills. (US EPA)",
        "Food that rots in landfills releases methane, a greenhouse gas far more potent than CO2 over the short term. (US EPA)",
        "The EPA's Wasted Food Scale ranks the options from best to worst: prevent waste, donate or share edible food, feed animals, compost, and last, landfill or incineration. (US EPA)",
        "Food loss and waste are estimated to cause about 8 to 10 percent of global greenhouse gas emissions. (UN Environment Programme)",
        "Households waste more food than restaurants or shops; planning meals, storing food well and eating leftovers first all help. (UN Environment Programme, Food Waste Index 2024)"
    ]

    /// Runs one tool on the phone and returns plain sentences. Small on-device models read
    /// labeled sentences far more reliably than raw JSON.
    static func runTool(_ name: String, input: [String: Any], stats: EcoStats?) -> (result: String, isError: Bool) {
        func kg(_ value: Double) -> String { ImpactFormat.kg(value) }

        if name == "get_environment_facts" {
            return (environmentFacts.map { "- " + $0 }.joined(separator: "\n"), false)
        }
        guard let stats else {
            return ("The student has turned off stats access.", true)
        }
        let summary = stats.summary

        switch name {
        case "get_my_impact":
            let weeks = summary.weeklyBags(weeks: 6).map(String.init).joined(separator: ", ")
            return ("""
            All time, you've rescued \(summary.bags) verified bags.
            Food you've rescued: \(kg(summary.foodKg)) (\(kg(summary.measuredKg)) weighed at pickup, \(kg(summary.estimatedKg)) estimated).
            CO2e you've avoided: about \(kg(summary.co2eKg)). This is an estimate (\(ImpactRules.co2ePerFoodKg) kg CO2e per kg of food).
            Your weekly streak: \(summary.weeklyStreak()) weeks in a row with a verified rescue.
            Your bags per week, last 6 weeks, oldest first: \(weeks).
            Your Rescue League points: \(summary.pointsThisWeek()) this week, \(summary.pointsAllTime) all time.
            """, false)

        case "get_my_rescues":
            let limit = min(max((input["limit"] as? Int) ?? 5, 1), 20)
            guard !stats.rescues.isEmpty else { return ("You have no verified rescues yet.", false) }
            let lines = stats.rescues.prefix(limit).map { rescue in
                "- \(rescue.verifiedAt.formatted(.dateTime.month(.abbreviated).day())): \(rescue.bags) bag\(rescue.bags == 1 ? "" : "s") from \(rescue.business) (\(rescue.location)), \(kg(rescue.foodKg)) of food, \(rescue.measuredKg == nil ? "estimated" : "weighed at pickup")."
            }
            return ("Your \(lines.count) most recent verified rescues, newest first (Surprise Bag contents aren't recorded):\n" + lines.joined(separator: "\n"), false)

        case "get_campus_impact":
            let campus = ImpactDemo.campusBase
            let percent = Int((Double(stats.campusBagsThisWeek) / Double(campus.weeklyGoal) * 100).rounded())
            return ("""
            This week, UCF students have rescued \(stats.campusBagsThisWeek) bags out of a weekly goal of \(campus.weeklyGoal) (\(percent) percent of the goal).
            All time, UCF has rescued \(campus.bagsAllTime.formatted()) bags, about \(kg(campus.measuredKg + campus.estimatedKg)) of food.
            CO2e avoided all time: about \(kg(campus.co2eKg)), an estimate.
            """, false)

        case "get_league_standing":
            let period: LeaguePeriod = (input["period"] as? String) == "all_time" ? .allTime : .week
            let periodName = period == .week ? "this week" : "all time"
            let yourPoints = period == .week ? summary.pointsThisWeek() : summary.pointsAllTime
            let entries = CampusLeague.entries(period: period, nickname: stats.leagueNickname, yourPoints: yourPoints)
            var lines = ["Campus Rescue League, \(periodName). One point per day with a verified pickup. Top 5:"]
            lines += entries.prefix(5).enumerated().map { "\($0.offset + 1). \($0.element.name), \($0.element.points) points" }
            if let you = entries.enumerated().first(where: { $0.element.isYou }) {
                lines.append("You play as \(you.element.name) and are ranked \(you.offset + 1) of \(entries.count) with \(you.element.points) points \(periodName).")
            } else {
                lines.append("You haven't joined the league, so you have no rank. You can join in Impact, League settings.")
            }
            return (lines.joined(separator: "\n"), false)

        default:
            return ("Unknown tool \(name).", true)
        }
    }

    // MARK: Chat

    /// Sends the conversation, runs any stats tools Claude asks for, and returns the answer.
    /// `messages` is the API-format history; this appends the assistant's turns (unchanged,
    /// including thinking blocks) and tool results so the next question continues it.
    func reply(messages: inout [[String: Any]], stats: EcoStats?) async throws -> (text: String, lookedAt: [String]) {
        var lookedAt: [String] = []
        for _ in 0...Self.maxToolRounds {
            let response = try await post(messages: messages, statsAccess: stats != nil)
            let content = response["content"] as? [[String: Any]] ?? []
            let stopReason = response["stop_reason"] as? String

            if stopReason == "refusal" {
                throw EcoKnightError.refused
            }
            messages.append(["role": "assistant", "content": content])

            let toolCalls = content.filter { $0["type"] as? String == "tool_use" }
            if stopReason == "tool_use", !toolCalls.isEmpty {
                // All results go back in one user message.
                let results: [[String: Any]] = toolCalls.map { call in
                    let name = call["name"] as? String ?? ""
                    let output = Self.runTool(name, input: call["input"] as? [String: Any] ?? [:], stats: stats)
                    let label = Self.label(forTool: name)
                    if !lookedAt.contains(label) { lookedAt.append(label) }
                    var block: [String: Any] = ["type": "tool_result", "tool_use_id": call["id"] as? String ?? "", "content": output.result]
                    if output.isError { block["is_error"] = true }
                    return block
                }
                messages.append(["role": "user", "content": results])
                continue
            }

            let text = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw EcoKnightError.unreadable }
            return (text, lookedAt)
        }
        throw EcoKnightError.unreadable
    }

    /// A student message for the API: optional photo first, then the text.
    static func studentMessage(text: String, photoJPEG: Data?) -> [String: Any] {
        var content: [[String: Any]] = []
        if let photoJPEG {
            content.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": photoJPEG.base64EncodedString()]
            ])
        }
        content.append(["type": "text", "text": text])
        return ["role": "user", "content": content]
    }

    // MARK: Transport

    private func post(messages: [[String: Any]], statsAccess: Bool) async throws -> [String: Any] {
        guard let key = APIKeyStore.load() else { throw EcoKnightError.noKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16_000,
            "system": Self.rules(statsAccess: statsAccess),
            "messages": messages
        ]
        body["tools"] = [Self.factsTool] + (statsAccess ? Self.statsTools : [])
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error.message ?? "Request failed"
            throw EcoKnightError.http(status, message)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EcoKnightError.unreadable
        }
        return object
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

    private struct APIErrorBody: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}

// MARK: - Grounded offline knowledge

/// Reviewed retrieval corpus that ships inside the app. EcoKnight retrieves the most relevant
/// passages for each question, which is safer and easier to update than pretending a small phone
/// model was fine-tuned on facts that may later change.
private struct EcoKnowledgeArticle {
    let title: String
    let keywords: Set<String>
    let answer: String
    let source: String
}

private enum EcoKnowledgeBase {
    static let articles: [EcoKnowledgeArticle] = [
        EcoKnowledgeArticle(
            title: "Why food waste affects climate",
            keywords: ["climate", "carbon", "co2", "methane", "landfill", "emission", "waste"],
            answer: "Food in a landfill breaks down without much oxygen and produces methane. Preventing edible food from becoming waste also avoids wasting the land, water, energy and fertilizer used to produce it. The EPA reports that food is the most common material landfilled in the United States.",
            source: "US EPA — Composting and Wasted Food Scale"
        ),
        EcoKnowledgeArticle(
            title: "Best order for handling surplus food",
            keywords: ["prevent", "donate", "share", "compost", "hierarchy", "surplus", "leftover"],
            answer: "Use edible food first: prevent surplus, then donate or share it. Composting recycles nutrients but does not recover the food as food. Landfill and incineration are last choices.",
            source: "US EPA — Wasted Food Scale"
        ),
        EcoKnowledgeArticle(
            title: "Scale of global food waste",
            keywords: ["global", "world", "household", "restaurant", "retail", "statistic", "percent"],
            answer: "UNEP estimated that 1.05 billion tonnes of food were wasted at household, food-service and retail level in 2022—about 19 percent of food available to consumers. Households accounted for roughly 60 percent of that total.",
            source: "UN Environment Programme — Food Waste Index Report 2024"
        ),
        EcoKnowledgeArticle(
            title: "Safe leftover basics",
            keywords: ["safe", "safety", "leftover", "store", "fridge", "refrigerator", "temperature", "spoil"],
            answer: "Refrigerate perishable food within two hours, or within one hour when it is above 90°F. Keep the refrigerator at 40°F or below. USDA guidance says most cooked leftovers should be used within three to four days. Follow a business label when it is stricter.",
            source: "USDA Food Safety and Inspection Service — Food Safety Basics"
        ),
        EcoKnowledgeArticle(
            title: "Freezing rescued food",
            keywords: ["freeze", "freezer", "thaw", "bread", "bagel", "muffin", "storage"],
            answer: "Freeze food while it is still fresh, in a sealed container labeled with the date. Bread and many baked goods freeze well. Thaw in the refrigerator, or use the microwave only when you will cook or eat the food promptly. USDA advises freezing leftovers within three to four days.",
            source: "USDA Food Safety and Inspection Service — Freezing and Food Safety"
        ),
        EcoKnowledgeArticle(
            title: "Dorm-friendly waste prevention",
            keywords: ["dorm", "student", "mini", "microwave", "meal", "shopping", "tip", "habit"],
            answer: "Keep an ‘eat first’ zone at eye level, label leftovers with the date, buy only what fits in the mini-fridge, freeze extra bread early, and plan one flexible leftover meal before shopping again. Share unopened extras while they are still usable.",
            source: "Practical guidance synthesized from US EPA food-waste prevention guidance"
        ),
        EcoKnowledgeArticle(
            title: "UCF recycling and food",
            keywords: ["ucf", "campus", "recycle", "recycling", "bin", "pizza", "pantry"],
            answer: "UCF's single-stream recycling accepts listed clean recyclables, but food waste and food-contaminated cardboard do not belong in those recycling bins. UCF recommends donating unopened non-perishable food to Knights Pantry. Check current bin labels because collection rules can change.",
            source: "UCF Facilities Operations — UCF Recycles"
        ),
        EcoKnowledgeArticle(
            title: "Allergens and Surprise Bag contents",
            keywords: ["allergy", "allergen", "ingredient", "gluten", "vegan", "vegetarian", "diet", "contents"],
            answer: "EcoKnight cannot verify ingredients or allergens from an image or a Surprise Bag description. Ask the business for ingredient and allergen information before eating. UCF Dining publishes nutrition and allergen menus for participating campus locations.",
            source: "UCF Dining Services — Dietary Needs at UCF"
        )
    ]

    static func retrieve(_ question: String, limit: Int = 3) -> [EcoKnowledgeArticle] {
        let lowercased = question.lowercased()
        let tokens = Set(lowercased.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        var scored: [(article: EcoKnowledgeArticle, score: Int)] = []
        for article in articles {
            var score = 0
            for keyword in article.keywords where tokens.contains(keyword) || lowercased.contains(keyword) {
                score += 1
            }
            if score > 0 {
                scored.append((article, score))
            }
        }
        scored.sort {
            $0.score == $1.score
                ? $0.article.title < $1.article.title
                : $0.score > $1.score
        }
        // Only the best matches, so a storage question doesn't also get the donation article.
        guard let best = scored.first?.score else { return [] }
        return scored.filter { $0.score == best }.prefix(limit).map(\.article)
    }

    static func context(for question: String) -> String {
        retrieve(question).map { "\($0.title): \($0.answer) Source: \($0.source)." }.joined(separator: "\n")
    }
}

// MARK: - Offline fallback (no key, no network)

enum EcoKnightOffline {
    /// Keyword answers, including the student's own numbers when stats access is on.
    static func answer(_ question: String, stats: EcoStats?) -> (text: String, lookedAt: [String]) {
        let q = question.lowercased()
        let asksCampusImpact = ["campus impact", "campus total", "campus goal", "how is campus", "how many bags at ucf"].contains { q.contains($0) }
        let asksAboutMe = asksCampusImpact || [
            "my impact", "my stats", "my rescue", "my bags", "my streak", "my points", "my rank", "my co2",
            "have i rescued", "did i rescue", "have i saved", "how much have i", "how many have i",
            "how am i doing", "streak", "league", "points", "rank"
        ].contains { q.contains($0) }

        if asksAboutMe, let stats {
            let s = stats.summary
            if q.contains("rank") || q.contains("league") || q.contains("point") {
                return ("You have \(s.pointsThisWeek()) league point\(s.pointsThisWeek() == 1 ? "" : "s") this week and \(s.pointsAllTime) all time. You earn one point for each day with a verified pickup.", ["your impact"])
            }
            if q.contains("streak") {
                return ("Your streak is \(s.weeklyStreak()) week\(s.weeklyStreak() == 1 ? "" : "s") in a row with at least one verified rescue.", ["your impact"])
            }
            if asksCampusImpact {
                return ("Campus has rescued \(stats.campusBagsThisWeek) of \(ImpactDemo.campusBase.weeklyGoal) bags toward this week's goal.", ["campus totals"])
            }
            return (String(format: "You've rescued %d bag%@, about %.1f kg of food (%.1f kg weighed, %.1f kg estimated). That's roughly %.1f kg CO2e avoided, an estimate.", s.bags, s.bags == 1 ? "" : "s", s.foodKg, s.measuredKg, s.estimatedKg, s.co2eKg), ["your impact"])
        }
        let matches = EcoKnowledgeBase.retrieve(question)
        if !matches.isEmpty {
            return grounded(matches)
        }
        return ("I work best on food waste, leftovers, climate impact, UCF recycling, Surprise Bags, and your verified KnightSaver impact. Try asking, ‘How should I store leftovers?’ or ‘Why does food waste affect climate?’", [])
    }

    private static func grounded(_ articles: [EcoKnowledgeArticle]) -> (text: String, lookedAt: [String]) {
        let text = articles.map(\.answer).joined(separator: "\n\n")
        return (text + "\n\nSources: " + articles.map(\.source).joined(separator: "; ") + ".", ["offline knowledge"])
    }
}

// MARK: - On-device model (no API key)

/// Apple's on-device language model (iOS 26, Apple Intelligence devices). Runs on the phone with
/// no API key and no network, and uses the same stats tools as Claude.
enum EcoKnightOnDeviceSupport {
    static var isAvailable: Bool {
        // The Simulator can report the system model as available while its model service never
        // completes generation. Use the reviewed instant fallback for reliable demos and tests.
        #if targetEnvironment(simulator)
        return false
        #else
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
        #endif
    }

    /// Why the on-device model can't run here, in plain words.
    static var unavailableReason: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return ""
            case .unavailable(.deviceNotEligible): return "This device doesn't support Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings to use on-device AI."
            case .unavailable(.modelNotReady): return "The on-device model is still downloading."
            case .unavailable: return "On-device AI isn't available."
            }
        }
        #endif
        return "On-device AI needs iOS 26."
    }
}

/// One on-device conversation. The session keeps its own history between questions.
final class EcoOnDeviceChat {
    private let stats: EcoStats?
    private var session: AnyObject?

    init(stats: EcoStats?) {
        self.stats = stats
    }

    func reply(to text: String) async throws -> (text: String, lookedAt: [String]) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let current = (session as? LanguageModelSession) ?? makeSession()
            session = current
            do {
                return try await answer(text, in: current)
            } catch LanguageModelSession.GenerationError.guardrailViolation, LanguageModelSession.GenerationError.refusal {
                throw EcoKnightError.refused
            } catch {
                // A full context, or the system model service failing while it loads:
                // start a fresh session and ask once more.
                let fresh = makeSession()
                session = fresh
                return try await answer(text, in: fresh)
            }
        }
        #endif
        throw EcoKnightError.unreadable
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func makeSession() -> LanguageModelSession {
        let tools: [any Tool] = stats.map { stats in
            [
                OnDeviceStatsTool(name: "get_my_impact", summary: "The student's own verified rescue totals, estimated CO2e, streak and league points. Use for questions about their impact or progress.", stats: stats),
                OnDeviceStatsTool(name: "get_my_rescues", summary: "The student's most recent verified pickups: business, date, bags, food weight. Use for questions about what or where they rescued.", stats: stats),
                OnDeviceStatsTool(name: "get_campus_impact", summary: "UCF campus totals from KnightSaver and the weekly goal. Use for questions about how campus is doing.", stats: stats),
                OnDeviceStatsTool(name: "get_league_standing", summary: "The Campus Rescue League leaderboard and the student's rank this week. Use for questions about the league or their rank.", stats: stats)
            ]
        } ?? []
        // The on-device model is small: give it the fact list up front instead of behind a tool,
        // and keep its rules short and blunt.
        let instructions = EcoKnightClient.rules(statsAccess: stats != nil) + """

        Extra rules:
        - Never mention tool names. Answer in your own words; don't paste tool output.
        - Do not state any number or name any source unless it appears in a tool result, in the reviewed context sent with the question, or in these facts:
        \(EcoKnightClient.environmentFacts.map { "- " + $0 }.joined(separator: "\n"))
        """
        return LanguageModelSession(tools: tools, instructions: instructions)
    }

    @available(iOS 26.0, *)
    private func answer(_ text: String, in session: LanguageModelSession) async throws -> (text: String, lookedAt: [String]) {
        let retrieved = EcoKnowledgeBase.context(for: text)
        let groundedPrompt = retrieved.isEmpty ? text : """
        Answer using the reviewed context below. If it does not answer the question, say what you do not know. Keep the source names in the answer.

        Reviewed context:
        \(retrieved)

        Student question: \(text)
        """
        let response = try await session.respond(to: groundedPrompt, options: GenerationOptions(temperature: 0.1))
        var lookedAt: [String] = []
        for entry in response.transcriptEntries {
            guard case .toolCalls(let calls) = entry else { continue }
            for call in calls {
                let label = EcoKnightClient.label(forTool: call.toolName)
                if !lookedAt.contains(label) { lookedAt.append(label) }
            }
        }
        return (response.content.trimmingCharacters(in: .whitespacesAndNewlines), lookedAt)
    }
    #endif
}

#if canImport(FoundationModels)
/// One read-only stats tool for the on-device model. Same data as the Claude tools.
@available(iOS 26.0, *)
private struct OnDeviceStatsTool: Tool {
    let name: String
    let summary: String
    let stats: EcoStats

    var description: String { summary }

    /// No arguments: a small model picks the right tool far more reliably than the right argument.
    /// Rescues default to the latest 5 and the league to this week.
    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        EcoKnightClient.runTool(name, input: [:], stats: stats).result
    }
}
#endif

// MARK: - Keychain

/// Stores the Claude API key on this device only.
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
