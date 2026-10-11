import Foundation

// MARK: - Stage 1: what the AI understood

struct SurplusInterpretation: Hashable {
    var inventory: [SurplusItem]
    var pickupStart: Date?
    var pickupEnd: Date?
    var price: Double?
    /// Missing or uncertain information, shown to staff.
    var notes: [String]
}

// MARK: - Stage 2: the proposed Surprise Bag plan

struct BagAllocation: Hashable {
    /// What goes into each bag (staff only).
    var bags: [[SurplusItem]]
    /// Items that did not fit, always shown to staff.
    var leftover: [SurplusItem]
}

struct BagPlan: Hashable {
    var inventory: [SurplusItem]
    var bagCount: Int
    var price: Double
    var pickupStart: Date
    var pickupEnd: Date
    var publicDescription: String
    /// Chosen from the campus pickup spots.
    var pickupLocation: PickupLocation = PickupLocation.campusSpots[0]
    /// On: contents stay a secret, even in the staff split. Off: a Rescue Bag with known contents.
    var isSurprise: Bool = true
    var createdByAI: Bool
    /// The business's bag limit per listing (Profile). The plan can't go above it.
    var maxBags: Int = BusinessRules.defaultMaxBagsPerListing

    var validInventory: [SurplusItem] {
        inventory.filter { $0.quantity > 0 && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var totalItems: Int { validInventory.totalUnits }

    /// Highest bag count staff can pick: one item per bag at least, and never above the limit.
    var bagCountCap: Int { max(1, min(totalItems, maxBags)) }

    var allocation: BagAllocation {
        SurplusAssistant.allocate(validInventory, into: bagCount)
    }

    var problems: [String] {
        var result: [String] = []
        if totalItems == 0 { result.append("Add at least one surplus item.") }
        if bagCount < 1 { result.append("Make at least 1 Surprise Bag.") }
        if bagCount > maxBags { result.append("Your limit is \(maxBags) bags per listing. Change it in Profile.") }
        if totalItems > 0 && bagCount > totalItems { result.append("There are more bags than surplus items.") }
        if price < 0 { result.append("Price can't be negative.") }
        if pickupEnd <= pickupStart { result.append("Pickup must end after it starts.") }
        return result
    }

    var isReady: Bool { problems.isEmpty }
}

// MARK: - Voice edits of a live listing

struct ProposedChange: Identifiable, Hashable {
    var id: String { field }
    let field: String
    let oldValue: String
    let newValue: String
}

enum ListingStateAction: Hashable {
    case pause
    case resume
    case close
    case cancel
}

struct ListingEditProposal: Hashable {
    var remainingQuantity: Int?
    var price: Double?
    var pickupStart: Date?
    var pickupEnd: Date?
    var stateAction: ListingStateAction?
    var changes: [ProposedChange]
    var notes: [String]
}

/// Turns what staff say (dictated or typed) into structured data with simple rules on the
/// phone. `SurplusAI` does the same job with Gemini; these rules are its offline fallback.
/// Both keep the same contract: only inventory staff reported, no allergen or dietary claims,
/// no food-safety approval, and nothing is published without staff approval.
enum SurplusAssistant {
    /// Words the speech recognizer should expect from kitchen staff.
    static let speechHints = [
        "bagels", "cookies", "pastries", "croissants", "muffins", "sandwiches", "wraps",
        "salads", "donuts", "Surprise Bag", "Rescue Bag", "pickup", "bags", "per bag",
        "Student Union", "Memory Mall", "Knight Pass"
    ]


    // MARK: Stage 1

    static func interpret(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> SurplusInterpretation {
        var working = normalize(text)
        var notes: [String] = []

        let price = extractPrice(from: &working)
        let times = extractPickupTimes(from: &working, now: now, calendar: calendar)
        // The "No pickup time heard" case gets its own, more helpful note below.
        notes.append(contentsOf: times.notes.filter { !$0.hasPrefix("No pickup") })
        let inventory = extractInventory(from: working)

        return withMissingNotes(SurplusInterpretation(
            inventory: inventory,
            pickupStart: times.start,
            pickupEnd: times.end,
            price: price,
            notes: notes
        ))
    }

    /// Adds the notes staff see when items, a pickup time or a price weren't heard.
    static func withMissingNotes(_ interpretation: SurplusInterpretation) -> SurplusInterpretation {
        var result = interpretation
        if result.inventory.isEmpty {
            result.notes.insert("I didn't hear any items with a quantity, like “12 bagels”. Add them below.", at: 0)
        }
        if result.pickupStart == nil && result.pickupEnd == nil {
            result.notes.append("No pickup time heard. Set the start and end below.")
        }
        if result.price == nil {
            result.notes.append("No price heard. The standard price of \(PickupTime.money(BusinessRules.defaultBagPrice)) per bag will be suggested.")
        }
        return result
    }

    // MARK: Stage 2

    static func proposePlan(
        inventory: [SurplusItem],
        price: Double?,
        pickupStart: Date,
        pickupEnd: Date,
        createdByAI: Bool,
        maxBags: Int = BusinessRules.defaultMaxBagsPerListing
    ) -> BagPlan {
        let total = inventory.totalUnits
        let bags = min(max(1, total / BusinessRules.targetItemsPerBag), max(1, maxBags))
        return BagPlan(
            inventory: inventory,
            bagCount: bags,
            price: price ?? BusinessRules.defaultBagPrice,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            publicDescription: BusinessRules.defaultPublicDescription,
            createdByAI: createdByAI,
            maxBags: max(1, maxBags)
        )
    }

    /// Spreads the items across bags so each bag gets a similar count and a mix of items.
    /// Never allocates more than staff reported. Anything over the per-bag limit is returned as leftover.
    static func allocate(_ items: [SurplusItem], into bagCount: Int) -> BagAllocation {
        let valid = items.filter { $0.quantity > 0 }
        guard bagCount > 0, !valid.isEmpty else {
            return BagAllocation(bags: [], leftover: valid)
        }

        // Deal units like cards, biggest item first, continuing round the bags.
        // 12 bagels, 6 pastries, 4 sandwiches into 7 bags gives every bag 3–4 items with a mix.
        let order = valid.indices.sorted { valid[$0].quantity > valid[$1].quantity }
        var sequence: [Int] = []
        for index in order {
            sequence.append(contentsOf: Array(repeating: index, count: valid[index].quantity))
        }

        let capacity = bagCount * BusinessRules.maxItemsPerBag
        var counts = Array(repeating: Array(repeating: 0, count: valid.count), count: bagCount)
        var leftoverCounts = Array(repeating: 0, count: valid.count)
        for (position, itemIndex) in sequence.enumerated() {
            if position < capacity {
                counts[position % bagCount][itemIndex] += 1
            } else {
                leftoverCounts[itemIndex] += 1
            }
        }

        let bags: [[SurplusItem]] = counts.map { row in
            row.enumerated().compactMap { pair in
                pair.element > 0 ? SurplusItem(name: valid[pair.offset].name, quantity: pair.element) : nil
            }
        }
        let leftover: [SurplusItem] = leftoverCounts.enumerated().compactMap { pair in
            pair.element > 0 ? SurplusItem(name: valid[pair.offset].name, quantity: pair.element) : nil
        }
        return BagAllocation(bags: bags, leftover: leftover)
    }

    // MARK: Edits

    static func proposeEdit(
        for listing: BusinessListing,
        instruction: String,
        maxBagsPerListing: Int = BusinessRules.defaultMaxBagsPerListing,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ListingEditProposal {
        var working = normalize(instruction)
        let lower = working
        let price = extractPrice(from: &working)
        let times = extractPickupTimes(from: &working, now: now, calendar: calendar, isEdit: true)
        var notes = times.notes.filter { !$0.hasPrefix("No pickup") }
        let quantity = tokenize(working).first(where: { Int($0) != nil }).flatMap { Int($0) }

        let action: ListingStateAction?
        if containsWord(lower, ["cancel"]) {
            action = .cancel
        } else if containsWord(lower, ["close", "sold out", "stop selling", "end it"]) {
            action = .close
        } else if containsWord(lower, ["pause", "hide", "hold"]) {
            action = .pause
        } else if containsWord(lower, ["resume", "unpause", "reopen", "restart"]) {
            action = .resume
        } else {
            action = nil
        }

        if lower.contains("allerg") || lower.contains("vegan") || lower.contains("gluten") || lower.contains("halal") {
            notes.append("Allergen and dietary claims can't be added. Surprise Bags never promise contents.")
        }
        return makeProposal(for: listing, quantity: quantity, price: price,
                            pickupStart: times.start, pickupEnd: times.end, action: action, notes: notes,
                            maxBagsPerListing: maxBagsPerListing)
    }

    /// Compares the values heard in an edit with the live listing and lists what would change.
    /// A start time alone keeps the pickup's length; an end time alone keeps the start when it can.
    static func makeProposal(
        for listing: BusinessListing,
        quantity: Int?,
        price: Double?,
        pickupStart: Date?,
        pickupEnd: Date?,
        action: ListingStateAction?,
        notes: [String],
        maxBagsPerListing: Int = BusinessRules.defaultMaxBagsPerListing
    ) -> ListingEditProposal {
        var proposal = ListingEditProposal(changes: [], notes: notes)
        let maxBagsAvailable = listing.maxBagsAvailable(limit: maxBagsPerListing)

        if let price, price >= 0, abs(price - listing.price) > 0.001 {
            proposal.price = price
            proposal.changes.append(ProposedChange(field: "Price",
                                                   oldValue: PickupTime.money(listing.price),
                                                   newValue: PickupTime.money(price)))
        }

        var newStart = pickupStart
        var newEnd = pickupEnd
        if newStart != nil && newEnd == nil, let start = newStart {
            // "Move pickup to 7:30" keeps the same length.
            newEnd = start.addingTimeInterval(listing.pickupEnd.timeIntervalSince(listing.pickupStart))
        } else if newEnd != nil && newStart == nil, let end = newEnd {
            newStart = min(listing.pickupStart, end.addingTimeInterval(-BusinessRules.defaultPickupLength))
        }
        if let start = newStart, let end = newEnd, start < end,
           start != listing.pickupStart || end != listing.pickupEnd {
            proposal.pickupStart = start
            proposal.pickupEnd = end
            proposal.changes.append(ProposedChange(field: "Pickup",
                                                   oldValue: listing.pickupWindowText,
                                                   newValue: PickupTime.window(start, end)))
        }

        if var quantity, quantity >= 0, quantity <= 500 {
            // The business's bag limit wins over whatever was heard.
            if quantity > maxBagsAvailable {
                proposal.notes.append("Your limit is \(maxBagsPerListing) bags per listing, so at most \(maxBagsAvailable) can be available here. Change the limit in Profile.")
                quantity = maxBagsAvailable
            }
            if quantity != listing.remainingQuantity {
                proposal.remainingQuantity = quantity
                proposal.changes.append(ProposedChange(field: "Bags available",
                                                       oldValue: "\(listing.remainingQuantity)",
                                                       newValue: "\(quantity)"))
            }
        }

        switch action {
        case .pause? where listing.state == .paused, .resume? where listing.state != .paused:
            break
        case let action?:
            proposal.stateAction = action
            let newValue: String
            switch action {
            case .pause: newValue = "Paused"
            case .resume: newValue = "Available"
            case .close: newValue = "Closed"
            case .cancel: newValue = "Cancelled"
            }
            proposal.changes.append(ProposedChange(field: "Status", oldValue: listing.status.rawValue, newValue: newValue))
        case nil:
            break
        }

        if proposal.changes.isEmpty {
            proposal.notes.append("I didn't find a change. Try: “Change the quantity to six bags and move pickup to 7:15–7:45 PM.”")
        }
        return proposal
    }

    // MARK: - Parsing helpers

    static func normalize(_ text: String) -> String {
        var result = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
        for (word, value) in numberWords {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: String(value))
        }
        return result
    }

    /// Finds the bag price and removes it from the text.
    static func extractPrice(from working: inout String) -> Double? {
        let patterns: [(pattern: String, divisor: Double)] = [
            (#"\$\s?(\d+(?:\.\d{1,2})?)"#, 1),
            (#"\b(\d+(?:\.\d{1,2})?)\s?(?:dollars?|bucks|usd)\b"#, 1),
            (#"\b(\d+)\s?cents?\b"#, 100),
            (#"\bpriced?\s+(?:(?:to|at|of|is)\s+)?(\d+(?:\.\d{1,2})?)"#, 1),
            (#"\b(?:for|at)\s+(\d+\.\d{1,2})\b"#, 1),
        ]
        var hits: [(location: Int, value: Double)] = []
        for item in patterns {
            for match in matches(item.pattern, in: working) {
                guard let text = group(match, 1, in: working), let number = Double(text) else { continue }
                hits.append((location: match.range.location, value: number / item.divisor))
                blank(match.range, in: &working)
            }
        }
        return hits.min(by: { $0.location < $1.location })?.value
    }

    struct PickupTimes {
        var start: Date?
        var end: Date?
        var notes: [String]
    }

    private static let meridiem = #"(?:\s*([ap])\.?\s?m\b\.?)?"#

    /// Finds "7:00 to 7:30 pm", "between 7 and 8", "7-7:30pm", or a single time like "by 8".
    static func extractPickupTimes(
        from working: inout String,
        now: Date,
        calendar: Calendar,
        isEdit: Bool = false
    ) -> PickupTimes {
        var result = PickupTimes(notes: [])

        // 1. A range.
        let rangePattern = #"(?:\b(from|between)\s+)?\b(\d{1,2})(?::(\d{2}))?"# + meridiem
            + #"\s*(?:-|–|—|to|until|till|through|and)\s*(\d{1,2})(?::(\d{2}))?"# + meridiem
        for match in matches(rangePattern, in: working) {
            let text = working
            let keyword = group(match, 1, in: text)
            guard let h1 = group(match, 2, in: text).flatMap({ Int($0) }),
                  let h2 = group(match, 5, in: text).flatMap({ Int($0) }) else { continue }
            let m1Text = group(match, 3, in: text)
            let m2Text = group(match, 6, in: text)
            let ap1 = group(match, 4, in: text)
            let ap2 = group(match, 7, in: text)
            // Avoid reading "12 and 6" as a time: needs a keyword, a colon or AM/PM.
            guard keyword != nil || m1Text != nil || m2Text != nil || ap1 != nil || ap2 != nil else { continue }
            let m1 = Int(m1Text ?? "0") ?? 0
            let m2 = Int(m2Text ?? "0") ?? 0
            guard m1 < 60, m2 < 60 else { continue }

            var assumed = false
            guard var end24 = to24Hour(h2, meridiem: ap2 ?? ap1, assumedPM: &assumed) else { continue }
            var start24: Int
            if let ap1 = ap1 {
                guard let value = to24Hour(h1, meridiem: ap1, assumedPM: &assumed) else { continue }
                start24 = value
            } else {
                guard let value = to24Hour(h1, meridiem: ap2, assumedPM: &assumed) else { continue }
                start24 = value
                // "11 to 1 pm" -> 11 AM to 1 PM
                if start24 * 60 + m1 >= end24 * 60 + m2 && start24 >= 12 { start24 -= 12 }
            }
            if end24 == 24 { end24 = 0 }
            guard let start = calendar.date(bySettingHour: start24, minute: m1, second: 0, of: now),
                  let end = calendar.date(bySettingHour: end24, minute: m2, second: 0, of: now),
                  start < end else { continue }
            result.start = start
            result.end = end
            if assumed { result.notes.append("Pickup time had no AM/PM, so I assumed PM.") }
            blank(match.range, in: &working)
            return result
        }

        // 2. A single time.
        let singlePatterns: [(pattern: String, hasMinutes: Bool, hasMeridiem: Bool)] = [
            (#"\b(\d{1,2})(?::(\d{2}))?\s*([ap])\.?\s?m\b\.?"#, true, true),
            (#"\b(\d{1,2}):(\d{2})\b"#, true, false),
            (#"\b(?:by|until|till|before|at|from|pickup|pick up|pick-up)\s+(?:(?:at|to)\s+)?(\d{1,2})\b(?!\s*(?:bags?|portions?|items?|boxes|box|pieces?|trays?|orders?))"#, false, false),
        ]
        for item in singlePatterns {
            for match in matches(item.pattern, in: working) {
                let text = working
                guard let hour = group(match, 1, in: text).flatMap({ Int($0) }) else { continue }
                let minute = item.hasMinutes ? (Int(group(match, 2, in: text) ?? "0") ?? 0) : 0
                guard minute < 60 else { continue }
                var assumed = false
                let meridiemText = item.hasMeridiem ? group(match, 3, in: text) : nil
                guard let hour24 = to24Hour(hour, meridiem: meridiemText, assumedPM: &assumed),
                      let date = calendar.date(bySettingHour: hour24 == 24 ? 0 : hour24, minute: minute, second: 0, of: now)
                else { continue }

                let before = textBefore(match.range, in: text, length: 14)
                let isEnd = ["by", "until", "till", "before", "ends", "end"].contains { before.contains($0) }
                    || ["by", "until", "till", "before"].contains { (group(match, 0, in: text) ?? "").hasPrefix($0) }
                if isEnd {
                    result.end = date
                    if !isEdit {
                        result.start = max(PickupTime.roundedDown(now), date.addingTimeInterval(-BusinessRules.defaultPickupLength))
                        result.notes.append("Only an end time was heard, so pickup starts 30 minutes earlier. Check it.")
                    }
                } else {
                    result.start = date
                    if !isEdit {
                        result.end = date.addingTimeInterval(BusinessRules.defaultPickupLength)
                        result.notes.append("Only a start time was heard, so pickup lasts 30 minutes. Check it.")
                    }
                }
                if assumed { result.notes.append("Pickup time had no AM/PM, so I assumed PM.") }
                blank(match.range, in: &working)
                return result
            }
        }

        result.notes.append("No pickup time heard.")
        return result
    }

    /// "12 bagels, 6 pastries, and 4 sandwiches" -> three items.
    static func extractInventory(from working: String) -> [SurplusItem] {
        let tokens = tokenize(working)
        var items: [SurplusItem] = []
        var index = 0
        while index < tokens.count {
            guard let quantity = Int(tokens[index]), quantity > 0, quantity <= 500 else {
                index += 1
                continue
            }
            var cursor = index + 1
            while cursor < tokens.count, itemLeadingFillers.contains(tokens[cursor]) {
                cursor += 1
            }
            var words: [String] = []
            while cursor < tokens.count, words.count < 5 {
                let token = tokens[cursor]
                if token == "and" {
                    // "mac and cheese" continues, "and 4 sandwiches" stops.
                    let next = cursor + 1 < tokens.count ? tokens[cursor + 1] : ""
                    if next.isEmpty || Int(next) != nil || !isWord(next) { break }
                    words.append(token)
                    cursor += 1
                    continue
                }
                guard isWord(token), !itemStopWords.contains(token) else { break }
                words.append(token)
                cursor += 1
            }
            while let last = words.last, ["and", "of", "the", "a", "with"].contains(last) {
                words.removeLast()
            }
            if !words.isEmpty {
                let name = capitalizedFirst(words.joined(separator: " "))
                if let existing = items.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
                    items[existing].quantity += quantity
                } else {
                    items.append(SurplusItem(name: name, quantity: quantity))
                }
            }
            index = max(cursor, index + 1)
        }
        return items
    }

    // MARK: Word lists

    private static let itemStopWords: Set<String> = [
        "left", "remaining", "leftover", "for", "at", "by", "until", "till", "before", "each",
        "pickup", "pick", "ready", "available", "today", "tonight", "price", "priced", "that",
        "which", "to", "from", "can", "be", "is", "are", "we", "have", "it", "they", "then",
        "please", "so", "but", "also", "plus", "between",
    ]

    private static let itemLeadingFillers: Set<String> = [
        "of", "the", "a", "an", "some", "extra", "leftover", "more", "about", "around", "like",
    ]

    private static let numberWords: [(String, Int)] = [
        ("half a dozen", 6), ("a dozen", 12), ("dozen", 12),
        ("one", 1), ("two", 2), ("three", 3), ("four", 4), ("five", 5), ("six", 6),
        ("seven", 7), ("eight", 8), ("nine", 9), ("ten", 10), ("eleven", 11), ("twelve", 12),
        ("thirteen", 13), ("fourteen", 14), ("fifteen", 15), ("sixteen", 16), ("seventeen", 17),
        ("eighteen", 18), ("nineteen", 19), ("twenty", 20), ("thirty", 30), ("forty", 40), ("fifty", 50),
    ]

    // MARK: Small helpers

    /// Converts to 24-hour time. No AM/PM: 1–11 are read as PM (pickups are in the evening).
    private static func to24Hour(_ hour: Int, meridiem: String?, assumedPM: inout Bool) -> Int? {
        if let meridiem = meridiem {
            guard (1...12).contains(hour) else { return nil }
            if meridiem == "p" { return hour == 12 ? 12 : hour + 12 }
            return hour == 12 ? 0 : hour
        }
        guard (0...23).contains(hour) else { return nil }
        if (1...11).contains(hour) {
            assumedPM = true
            return hour + 12
        }
        return hour
    }

    static func tokenize(_ text: String) -> [String] {
        matches(#"[a-z0-9'&\-]+|[,.;!?]"#, in: text).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private static func isWord(_ token: String) -> Bool {
        if token == "&" { return true }
        guard let first = token.unicodeScalars.first else { return false }
        return CharacterSet.letters.contains(first)
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
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

    /// Replaces a range with "," plus spaces, keeping the length, so it acts as a separator.
    private static func blank(_ range: NSRange, in text: inout String) {
        guard range.length > 0 else { return }
        let replacement = "," + String(repeating: " ", count: range.length - 1)
        text = (text as NSString).replacingCharacters(in: range, with: replacement)
    }

    private static func containsWord(_ text: String, _ words: [String]) -> Bool {
        words.contains { word in
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            return !matches(pattern, in: text).isEmpty
        }
    }
}

// MARK: - Gemini

/// Reads staff speech with Gemini. It returns the same types as `SurplusAssistant`, so the
/// screens don't change and staff still review every result. Callers fall back to
/// `SurplusAssistant` when this throws (no key, offline, no answer).
enum SurplusAI {
    private static let rules = """
    You read what restaurant staff said and turn it into data for KnightSaver, a UCF app where \
    students pick up surplus food in Surprise Bags. Staff speak into a phone, so the text may have \
    speech-to-text mistakes, like "for" instead of "4" or "bagel's" instead of "bagels". Fix obvious ones.
    Rules:
    - Use only items, numbers, prices and times staff actually said. Never invent anything.
    - Never add allergen, dietary, ingredient or freshness claims. If staff mention them, add a note \
    that Surprise Bags can't promise contents.
    - Times are 24-hour "HH:mm" today. Pickups are usually in the afternoon or evening. If staff give \
    no AM or PM, choose the sensible reading and add a note saying what you assumed.
    - Notes are short sentences for staff about anything unclear. No notes when everything is clear.
    """

    // MARK: List surplus

    static func interpret(
        _ text: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> SurplusInterpretation {
        struct Reply: Decodable {
            struct Item: Decodable {
                let name: String
                let quantity: Int
            }
            let items: [Item]
            let pickupStart: String?
            let pickupEnd: String?
            let price: Double?
            let notes: [String]
        }
        let reply: Reply = try await ask("""
            It is \(clock(now, calendar: calendar)) now. Staff said: "\(text)"
            List each surplus item with its quantity, merging repeats of the same item. Give the pickup \
            start and end if staff said them, and the price per bag in US dollars if staff said one. \
            Use null for anything staff didn't say.
            """, schema: object([
                "items": ["type": "array", "items": object(["name": string, "quantity": integer])],
                "pickupStart": nullable("string"),
                "pickupEnd": nullable("string"),
                "price": nullable("number"),
                "notes": ["type": "array", "items": string]
            ]))

        var inventory: [SurplusItem] = []
        for item in reply.items {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, (1...500).contains(item.quantity) else { continue }
            if let index = inventory.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
                inventory[index].quantity += item.quantity
            } else {
                inventory.append(SurplusItem(name: name.prefix(1).uppercased() + name.dropFirst(), quantity: item.quantity))
            }
        }

        var start = reply.pickupStart.flatMap { time($0, on: now, calendar: calendar) }
        var end = reply.pickupEnd.flatMap { time($0, on: now, calendar: calendar) }
        var notes = reply.notes
        if start == nil, let heardEnd = end {
            start = max(PickupTime.roundedDown(now), heardEnd.addingTimeInterval(-BusinessRules.defaultPickupLength))
            notes.append("Only an end time was heard, so pickup starts 30 minutes earlier. Check it.")
        } else if end == nil, let heardStart = start {
            end = heardStart.addingTimeInterval(BusinessRules.defaultPickupLength)
            notes.append("Only a start time was heard, so pickup lasts 30 minutes. Check it.")
        }

        return SurplusAssistant.withMissingNotes(SurplusInterpretation(
            inventory: inventory,
            pickupStart: start,
            pickupEnd: end,
            price: reply.price.flatMap { $0 >= 0 ? $0 : nil },
            notes: notes
        ))
    }

    // MARK: Edit listing

    static func proposeEdit(
        for listing: BusinessListing,
        instruction: String,
        maxBagsPerListing: Int = BusinessRules.defaultMaxBagsPerListing,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> ListingEditProposal {
        struct Reply: Decodable {
            let bagsAvailable: Int?
            let price: Double?
            let pickupStart: String?
            let pickupEnd: String?
            let status: String
            let notes: [String]
        }
        let reply: Reply = try await ask("""
            It is \(clock(now, calendar: calendar)) now. The live listing has \(listing.remainingQuantity) of \
            \(listing.totalQuantity) bags available, costs \(PickupTime.money(listing.price)) per bag, has \
            pickup from \(clock(listing.pickupStart, calendar: calendar)) to \(clock(listing.pickupEnd, calendar: calendar)), \
            and its status is \(listing.status.rawValue). The business allows at most \
            \(listing.maxBagsAvailable(limit: maxBagsPerListing)) bags available on this listing.
            Staff said: "\(instruction)"
            Give only what staff asked to change, and null for everything else. bagsAvailable is the new \
            number of bags left. status is "pause", "resume", "close" (stop selling), "cancel", or "none".
            """, schema: object([
                "bagsAvailable": nullable("integer"),
                "price": nullable("number"),
                "pickupStart": nullable("string"),
                "pickupEnd": nullable("string"),
                "status": ["type": "string", "enum": ["none", "pause", "resume", "close", "cancel"]],
                "notes": ["type": "array", "items": string]
            ]))

        let action: ListingStateAction? = switch reply.status {
        case "pause": .pause
        case "resume": .resume
        case "close": .close
        case "cancel": .cancel
        default: nil
        }
        return SurplusAssistant.makeProposal(
            for: listing,
            quantity: reply.bagsAvailable,
            price: reply.price,
            pickupStart: reply.pickupStart.flatMap { time($0, on: now, calendar: calendar) },
            pickupEnd: reply.pickupEnd.flatMap { time($0, on: now, calendar: calendar) },
            action: action,
            notes: reply.notes,
            maxBagsPerListing: maxBagsPerListing
        )
    }

    // MARK: Transport

    /// One structured-output call: Gemini's reply is JSON that matches `schema`.
    private static func ask<Reply: Decodable>(_ prompt: String, schema: [String: Any]) async throws -> Reply {
        let content = try await GeminiAPI.generate([
            "systemInstruction": ["parts": [["text": rules]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseJsonSchema": schema,
                // Low thinking: a short extraction while staff wait at the counter.
                "thinkingConfig": ["thinkingLevel": "low"]
            ]
        ])
        guard let data = GeminiAPI.text(of: content).data(using: .utf8),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw GeminiAPI.Failure.unreadable }
        return reply
    }

    private static let string: [String: Any] = ["type": "string"]
    private static let integer: [String: Any] = ["type": "integer"]

    private static func nullable(_ type: String) -> [String: Any] {
        ["type": [type, "null"]]
    }

    /// Every property required and nothing extra, so replies always have the same shape.
    private static func object(_ properties: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": properties, "required": properties.keys.sorted(), "additionalProperties": false]
    }

    // MARK: Times

    private static func clock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// "19:30" → today at 7:30 PM.
    private static func time(_ text: String, on day: Date, calendar: Calendar) -> Date? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }
}
