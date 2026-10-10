import Foundation

/// One field the assistant wants to change. Staff approve before it is applied.
struct ProposedChange: Identifiable, Equatable {
    var id: String { field }
    let field: String
    let oldValue: String
    let newValue: String
}

enum ListingStatusAction: Equatable {
    case pause
    case resume
    case close
}

/// Turns what staff say (typed, or dictated with the keyboard microphone) into a listing draft.
///
/// This version runs fully on the phone with simple rules, so the demo works without
/// internet or an API key. It can be swapped for a real language model later, as long as
/// it keeps the same safety rules:
/// - It never fills in allergens.
/// - It never confirms food safety.
/// - Staff review everything before it goes live.
enum ListingAssistant {

    struct DraftResult {
        var draft: ListingDraft
        /// Fields the assistant filled in, e.g. ["Name", "Quantity"].
        var filledFields: [String]
        var notes: [String]
    }

    struct EditProposal {
        var draft: ListingDraft
        var statusAction: ListingStatusAction?
        var changes: [ProposedChange]
        var notes: [String]
    }

    // MARK: - New listing

    static func makeDraft(from text: String, now: Date = Date(), calendar: Calendar = .current) -> DraftResult {
        let parsed = parse(text, now: now, calendar: calendar)
        var draft = ListingDraft()
        var filled: [String] = []
        var notes: [String] = []

        if let name = parsed.name {
            draft.name = name
            filled.append("Name")
        } else {
            notes.append("I couldn't tell what the food is. Please add a name.")
        }
        if let quantity = parsed.quantity {
            draft.quantity = quantity
            filled.append("Quantity")
        } else {
            notes.append("No quantity heard, so it's set to 1.")
        }
        if let price = parsed.price {
            draft.price = price
            filled.append("Price")
        } else {
            notes.append("No price heard. Please add one.")
        }
        if let original = parsed.originalPrice {
            draft.originalPrice = original
            filled.append("Normal price")
        } else {
            notes.append("Add the normal menu price so student savings can be counted.")
        }
        if let deadline = parsed.deadline {
            draft.pickupDeadline = deadline
            filled.append("Pickup deadline")
        }
        if let assumption = parsed.timeAssumption {
            notes.append(assumption)
        }
        notes.append("Allergens and food safety must be entered and confirmed by staff.")

        return DraftResult(draft: draft, filledFields: filled, notes: notes)
    }

    // MARK: - Edit existing listing

    static func proposeEdit(
        for listing: Listing,
        instruction: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> EditProposal {
        let lower = instruction.lowercased()
        let parsed = parse(instruction, now: now, calendar: calendar, isEdit: true)
        var draft = ListingDraft(listing: listing)
        var changes: [ProposedChange] = []
        var notes: [String] = []

        if let newName = parsed.rename, newName != listing.name {
            draft.name = newName
            changes.append(ProposedChange(field: "Name", oldValue: listing.name, newValue: newName))
        }
        if let quantity = parsed.quantity, quantity != listing.quantityRemaining {
            draft.quantity = quantity
            changes.append(ProposedChange(field: "Quantity",
                                          oldValue: "\(listing.quantityRemaining)",
                                          newValue: "\(quantity)"))
        }
        if let price = parsed.price, abs(price - listing.price) > 0.001 {
            draft.price = price
            changes.append(ProposedChange(field: "Price",
                                          oldValue: money(listing.price),
                                          newValue: money(price)))
        }
        if let original = parsed.originalPrice, abs(original - listing.originalPrice) > 0.001 {
            draft.originalPrice = original
            changes.append(ProposedChange(field: "Normal price",
                                          oldValue: money(listing.originalPrice),
                                          newValue: money(original)))
        }
        if let deadline = parsed.deadline, deadline != listing.pickupDeadline {
            draft.pickupDeadline = deadline
            changes.append(ProposedChange(field: "Pickup deadline",
                                          oldValue: time(listing.pickupDeadline),
                                          newValue: time(deadline)))
        }
        if let assumption = parsed.timeAssumption {
            notes.append(assumption)
        }

        var statusAction: ListingStatusAction?
        if containsWord(lower, ["close", "closed", "end", "stop selling", "sold out"]) {
            statusAction = .close
            changes.append(ProposedChange(field: "Status", oldValue: listing.status.label, newValue: "Closed"))
        } else if containsWord(lower, ["pause", "hold", "hide"]) {
            if !listing.isPaused {
                statusAction = .pause
                changes.append(ProposedChange(field: "Status", oldValue: listing.status.label, newValue: "Paused"))
            }
        } else if containsWord(lower, ["resume", "unpause", "reopen", "open it", "make it available"]) {
            if listing.isPaused {
                statusAction = .resume
                changes.append(ProposedChange(field: "Status", oldValue: listing.status.label, newValue: "Available"))
            }
        }

        if lower.contains("allergen") || lower.contains("allergy") || lower.contains("allergies") {
            notes.append("Allergens can only be changed by staff in the manual form.")
        }
        if changes.isEmpty {
            notes.append("I didn't find a change. Try something like: \"Change to 6 portions and move pickup to 7:30.\"")
        }

        return EditProposal(draft: draft, statusAction: statusAction, changes: changes, notes: notes)
    }

    // MARK: - Formatting helpers

    static func money(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Parsing

    struct Parsed {
        var name: String?
        var rename: String?
        var quantity: Int?
        var price: Double?
        var originalPrice: Double?
        var deadline: Date?
        var timeAssumption: String?
    }

    static func parse(_ raw: String, now: Date, calendar: Calendar, isEdit: Bool = false) -> Parsed {
        var result = Parsed()
        let normalized = replaceNumberWords(in: raw.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\n", with: " "))
        // Blanked-out copy: every piece we understand is replaced with a "," so it
        // acts as a stop when we look for the food name and quantity.
        var working = normalized

        // 1. Prices
        let pricePatterns: [(pattern: String, divisor: Double)] = [
            (#"\$\s?(\d+(?:\.\d{1,2})?)"#, 1),
            (#"\b(\d+(?:\.\d{1,2})?)\s?(?:dollars?|bucks|usd)\b"#, 1),
            (#"\b(\d+)\s?cents?\b"#, 100),
            (#"\bpriced?\s+(?:(?:to|at|of|is)\s+)?(\d+(?:\.\d{1,2})?)"#, 1),
            (#"\b(?:for|at)\s+(\d+\.\d{1,2})\b"#, 1),
        ]
        var priceHits: [(location: Int, value: Double, isOriginal: Bool)] = []
        for item in pricePatterns {
            for match in matches(item.pattern, in: working) {
                guard let text = group(match, 1, in: working), let number = Double(text) else { continue }
                let before = textBefore(match.range, in: working, length: 24)
                let originalWords = ["original", "regular", "normal", "usual", "was ", "retail", "menu price", "instead of", "worth"]
                let isOriginal = originalWords.contains { before.contains($0) }
                priceHits.append((location: match.range.location, value: number / item.divisor, isOriginal: isOriginal))
                blank(match.range, in: &working)
            }
        }
        priceHits.sort { $0.location < $1.location }
        result.price = priceHits.first(where: { !$0.isOriginal })?.value
        result.originalPrice = priceHits.first(where: { $0.isOriginal })?.value

        // 2. Pickup time
        let timePatterns: [(pattern: String, hasMinutes: Bool, hasMeridiem: Bool)] = [
            (#"\b(\d{1,2})(?::(\d{2}))?\s*([ap])\.?\s?m(?![a-z])\.?"#, true, true),
            (#"\b(\d{1,2}):(\d{2})\b"#, true, false),
            (#"\b(?:by|until|till|before|pickup|pick up|pick-up)\s+(?:at\s+)?(\d{1,2})\b(?!\s*(?:portions?|servings?|boxes|box|packs?|packages?|pieces?|items?|orders?|trays?))"#, false, false),
        ]
        timeSearch: for item in timePatterns {
            for match in matches(item.pattern, in: working) {
                let text = working
                guard let hourText = group(match, 1, in: text), var hour = Int(hourText) else { continue }
                let minute = item.hasMinutes ? Int(group(match, 2, in: text) ?? "0") ?? 0 : 0
                guard minute < 60 else { continue }

                if item.hasMeridiem, let meridiem = group(match, 3, in: text) {
                    guard (1...12).contains(hour) else { continue }
                    if meridiem == "p" && hour < 12 { hour += 12 }
                    if meridiem == "a" && hour == 12 { hour = 0 }
                } else {
                    guard hour <= 23 else { continue }
                    if (1...11).contains(hour) {
                        hour += 12
                        result.timeAssumption = "Pickup time heard without AM/PM, so I assumed PM."
                    }
                }
                if let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) {
                    result.deadline = date
                    blank(match.range, in: &working)
                    break timeSearch
                }
            }
        }

        // 3. Rename (edits only): "rename to ...", "call it ..."
        let tokens = tokenize(working)
        if isEdit {
            let renameTriggers: [[String]] = [["rename", "it", "to"], ["rename", "to"], ["change", "the", "name", "to"],
                                              ["call", "it"], ["name", "it"], ["rename"]]
            for trigger in renameTriggers {
                if let start = find(trigger, in: tokens) {
                    let words = collectName(tokens, from: start + trigger.count)
                    if !words.isEmpty {
                        result.rename = titleCase(words)
                        break
                    }
                }
            }
        }

        // 4. Quantity: first whole number left after prices and times are removed.
        let quantityIndex = tokens.firstIndex { Int($0) != nil }
        if let index = quantityIndex, let value = Int(tokens[index]), value > 0, value <= 999 {
            result.quantity = value
        }

        // 5. Food name (new listings only)
        if !isEdit {
            var words: [String] = []
            if let index = quantityIndex {
                var start = index + 1
                if start < tokens.count, unitWords.contains(tokens[start]) {
                    start += 1
                }
                if start < tokens.count, tokens[start] == "of" {
                    start += 1
                }
                words = collectName(tokens, from: start)
                if words.isEmpty {
                    // "Chicken bowls, 6 left" -> look at the words before the number.
                    var back = index - 1
                    var reversed: [String] = []
                    while back >= 0, isNameWord(tokens[back]), reversed.count < 6 {
                        reversed.append(tokens[back])
                        back -= 1
                    }
                    words = trimFillers(Array(reversed.reversed()))
                }
            }
            if words.isEmpty {
                words = collectName(tokens, from: 0)
            }
            if !words.isEmpty {
                result.name = titleCase(words)
            }
        }

        return result
    }

    // MARK: - Word lists

    private static let unitWords: Set<String> = [
        "portion", "portions", "serving", "servings", "box", "boxes", "pack", "packs",
        "package", "packages", "piece", "pieces", "order", "orders", "tray", "trays",
        "container", "containers", "plate", "plates",
    ]

    private static let stopWords: Set<String> = [
        "for", "at", "by", "until", "till", "before", "each", "pickup", "pick", "ready",
        "available", "left", "remaining", "price", "priced", "originally", "regular",
        "regularly", "normally", "usually", "was", "that", "which", "to", "from", "today",
        "tonight", "now", "please", "it's", "is", "are", "cost", "costs", "move", "them",
        "those", "these", "it",
    ]

    private static let leadingFillers: Set<String> = [
        "we", "have", "i", "got", "we've", "i've", "there", "are", "is", "list", "listing",
        "add", "selling", "sell", "today", "about", "around", "some", "um", "uh", "so",
        "okay", "ok", "hi", "hey", "the", "of", "and", "a", "an", "new", "please", "can",
        "you", "post", "put", "up", "like",
    ]

    private static let trailingFillers: Set<String> = ["and", "with", "of", "the", "a", "an", "in"]

    private static let numberWords: [(String, Int)] = [
        ("half a dozen", 6), ("a dozen", 12), ("dozen", 12),
        ("one", 1), ("two", 2), ("three", 3), ("four", 4), ("five", 5), ("six", 6),
        ("seven", 7), ("eight", 8), ("nine", 9), ("ten", 10), ("eleven", 11), ("twelve", 12),
        ("thirteen", 13), ("fourteen", 14), ("fifteen", 15), ("sixteen", 16), ("seventeen", 17),
        ("eighteen", 18), ("nineteen", 19), ("twenty", 20), ("thirty", 30), ("forty", 40), ("fifty", 50),
    ]

    // MARK: - Small helpers

    private static func replaceNumberWords(in text: String) -> String {
        var result = text
        for (word, value) in numberWords {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: String(value))
        }
        return result
    }

    private static func matches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return nil }
        return String(text[range])
    }

    private static func textBefore(_ range: NSRange, in text: String, length: Int) -> String {
        let start = max(0, range.location - length)
        return (text as NSString).substring(with: NSRange(location: start, length: range.location - start))
    }

    /// Replaces a range with "," plus spaces, keeping the string length the same.
    private static func blank(_ range: NSRange, in text: inout String) {
        guard range.length > 0 else { return }
        let replacement = "," + String(repeating: " ", count: range.length - 1)
        text = (text as NSString).replacingCharacters(in: range, with: replacement)
    }

    private static func tokenize(_ text: String) -> [String] {
        matches(#"[a-z0-9'&\-]+|[,.;!?]"#, in: text).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private static func isNameWord(_ token: String) -> Bool {
        if token == "&" { return true }
        guard let first = token.unicodeScalars.first else { return false }
        if !CharacterSet.letters.contains(first) { return false }
        return !stopWords.contains(token)
    }

    /// Words from `start` until a stop word, number or punctuation. Max 6 words.
    private static func collectName(_ tokens: [String], from start: Int) -> [String] {
        var words: [String] = []
        var index = start
        // Skip filler at the beginning ("we have", "the", ...).
        while index < tokens.count, leadingFillers.contains(tokens[index]) {
            index += 1
        }
        while index < tokens.count, isNameWord(tokens[index]), words.count < 6 {
            words.append(tokens[index])
            index += 1
        }
        return trimFillers(words)
    }

    private static func trimFillers(_ words: [String]) -> [String] {
        var result = words
        while let first = result.first, leadingFillers.contains(first) { result.removeFirst() }
        while let last = result.last, trailingFillers.contains(last) { result.removeLast() }
        return result
    }

    private static func find(_ phrase: [String], in tokens: [String]) -> Int? {
        guard !phrase.isEmpty, tokens.count >= phrase.count else { return nil }
        for start in 0...(tokens.count - phrase.count) where Array(tokens[start..<start + phrase.count]) == phrase {
            return start
        }
        return nil
    }

    private static func containsWord(_ text: String, _ words: [String]) -> Bool {
        words.contains { word in
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            return !matches(pattern, in: text).isEmpty
        }
    }

    private static func titleCase(_ words: [String]) -> String {
        words.map { (word: String) -> String in
            guard let first = word.first else { return word }
            return first.uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }
}
