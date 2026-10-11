import Foundation

/// Public connection details for the KnightSaver Supabase project. The publishable
/// key is intentionally safe to ship in the app; database access is enforced by RLS.
enum BackendConfiguration {
    static let projectURL = URL(string: "https://prbohivlnyodesbiavyu.supabase.co")!
    static let publishableKey = "sb_publishable_mAtrSNSHgwUmFvv13e-kzg_rHA4Hju2"
}

struct BackendAuthSession: Codable, Hashable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: BackendUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct BackendUser: Codable, Hashable {
    struct Metadata: Codable, Hashable {
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    let id: UUID
    let email: String?
    let metadata: Metadata?

    enum CodingKeys: String, CodingKey {
        case id, email
        case metadata = "user_metadata"
    }
}

struct BackendReservationResult: Decodable, Hashable {
    let kind: String
    let reservationID: UUID?
    let waitlistID: UUID?
    let code: String?
    let position: Int?

    enum CodingKeys: String, CodingKey {
        case kind, code, position
        case reservationID = "reservation_id"
        case waitlistID = "waitlist_id"
    }
}

struct RemoteListing: Decodable, Identifiable, Hashable {
    let id: UUID
    let businessID: UUID
    let locationID: UUID
    let businessName: String
    let brandKey: String
    let label: String
    let isSurprise: Bool
    let priceCents: Int
    let totalQuantity: Int
    let remainingQuantity: Int
    let pickupStart: Date
    let pickupEnd: Date
    let publicDescription: String
    let bannerAssetName: String
    let status: String
    let address: String
    let latitude: Double
    let longitude: Double
    let rating: Double
    let feedbackCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, label, status, address, latitude, longitude, rating
        case businessID = "business_id"
        case locationID = "location_id"
        case businessName = "business_name"
        case brandKey = "brand_key"
        case isSurprise = "is_surprise"
        case priceCents = "price_cents"
        case totalQuantity = "total_quantity"
        case remainingQuantity = "remaining_quantity"
        case pickupStart = "pickup_start"
        case pickupEnd = "pickup_end"
        case publicDescription = "public_description"
        case bannerAssetName = "banner_asset_name"
        case feedbackCount = "feedback_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BackendBusinessSettings: Decodable, Hashable {
    let businessID: UUID
    let maxBagsPerListing: Int

    enum CodingKeys: String, CodingKey {
        case businessID = "business_id"
        case maxBagsPerListing = "max_bags_per_listing"
    }
}

/// The student's rewards from `get_my_rewards`, counted from staff-verified pickups.
struct RemoteRewards: Decodable, Hashable {
    let orders: Int
    let bags: Int
    let kitchens: Int
    let weeklyStreak: Int
    let measuredKg: Double
    let co2eKg: Double
    let nightPickup: Bool
    let cashEarnedCents: Int
    let cashSpentCents: Int
    /// Partner rewards already used at the shop.
    let redeemed: [RemotePartnerRedemption]
    let pointsThisWeek: Int
    let pointsAllTime: Int
    let leagueOptIn: Bool
    let leagueNickname: String?

    enum CodingKeys: String, CodingKey {
        case orders, bags, kitchens, redeemed
        case weeklyStreak = "weekly_streak"
        case measuredKg = "measured_kg"
        case co2eKg = "co2e_kg"
        case nightPickup = "night_pickup"
        case cashEarnedCents = "cash_earned_cents"
        case cashSpentCents = "cash_spent_cents"
        case pointsThisWeek = "points_this_week"
        case pointsAllTime = "points_all_time"
        case leagueOptIn = "league_opt_in"
        case leagueNickname = "league_nickname"
    }
}

/// A partner reward used at the shop, from `get_my_rewards` or `redeem_partner_reward`.
struct RemotePartnerRedemption: Decodable, Hashable {
    let rewardID: String
    let code: String
    let redeemedAt: Date

    enum CodingKeys: String, CodingKey {
        case code
        case rewardID = "reward_id"
        case redeemedAt = "redeemed_at"
    }
}

/// One period of the Campus Rescue League from `get_league`: nicknames only.
struct RemoteLeague: Decodable, Hashable {
    struct Row: Decodable, Hashable {
        let rank: Int
        let nickname: String
        let points: Int
        let isYou: Bool

        enum CodingKeys: String, CodingKey {
            case rank, nickname, points
            case isYou = "is_you"
        }
    }

    let entries: [Row]
    let you: Row?
    let weekEndsAt: Date

    enum CodingKeys: String, CodingKey {
        case entries, you
        case weekEndsAt = "week_ends_at"
    }
}

/// A student's Saver Cash at this counter, from `scan_rewards` (kitchen staff only).
struct RemoteRewardScan: Decodable, Hashable {
    let studentDisplayName: String
    let verifiedPickups: Int
    let cashBalanceCents: Int

    enum CodingKeys: String, CodingKey {
        case studentDisplayName = "student_display_name"
        case verifiedPickups = "verified_pickups"
        case cashBalanceCents = "cash_balance_cents"
    }
}

/// Saver Cash taken off a bill, from `redeem_saver_cash`.
struct RemoteCashRedemption: Decodable, Hashable {
    /// "redeemed", or "already_redeemed" when the same bill was sent again.
    let kind: String
    let amountCents: Int
    let balanceCents: Int

    enum CodingKeys: String, CodingKey {
        case kind
        case amountCents = "amount_cents"
        case balanceCents = "balance_cents"
    }
}

enum BackendError: LocalizedError {
    case invalidResponse
    case server(String)
    case notDeployed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The KnightSaver service returned an unreadable response."
        case .notDeployed: "This feature isn't set up on the KnightSaver service yet."
        case .server(let message): message
        }
    }
}

/// Lightweight Supabase client built on URLSession so the hackathon app does not
/// need another package dependency. Privileged mutations remain database RPCs.
actor KnightSaverBackend {
    static let shared = KnightSaverBackend()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Invalid ISO-8601 date: \(value)"
                )
            }
            return date
        }
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    func fetchLiveListings() async throws -> [RemoteListing] {
        var components = URLComponents(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/live_listings"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "pickup_start.asc")
        ]
        let data = try await request(url: components.url!, method: "GET")
        return try decoder.decode([RemoteListing].self, from: data)
    }

    func signIn(email: String, password: String) async throws -> BackendAuthSession {
        var components = URLComponents(
            url: BackendConfiguration.projectURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        let body = try encoder.encode(["email": email, "password": password])
        let data = try await request(url: components.url!, method: "POST", body: body)
        return try decoder.decode(BackendAuthSession.self, from: data)
    }

    /// Emails a one-time code. An address without an account gets one, confirmed when the code
    /// is entered. The code is the `{{ .Token }}` in the project's Confirm signup and Magic Link
    /// email templates.
    func sendEmailCode(email: String, displayName: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "create_user": true,
            "data": ["display_name": displayName]
        ])
        _ = try await request(
            url: BackendConfiguration.projectURL.appending(path: "auth/v1/otp"),
            method: "POST",
            body: body
        )
    }

    /// Checks the emailed code and returns the new session. The email is verified from here on.
    func verifyEmailCode(email: String, code: String) async throws -> BackendAuthSession {
        let body = try JSONSerialization.data(withJSONObject: ["type": "email", "email": email, "token": code])
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "auth/v1/verify"),
            method: "POST",
            body: body
        )
        return try decoder.decode(BackendAuthSession.self, from: data)
    }

    /// Sets the password the student chose, so later sign-ins use email and password.
    func setPassword(_ password: String, accessToken: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["password": password])
        _ = try await request(
            url: BackendConfiguration.projectURL.appending(path: "auth/v1/user"),
            method: "PUT",
            body: body,
            accessToken: accessToken
        )
    }

    func bootstrapIdentity(accessToken: String) async throws -> String {
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/bootstrap_demo_identity"),
            method: "POST",
            body: Data("{}".utf8),
            accessToken: accessToken
        )
        return try decoder.decode(String.self, from: data)
    }

    func knightPassToken(accessToken: String) async throws -> String {
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/get_knight_pass_token"),
            method: "POST",
            body: Data("{}".utf8),
            accessToken: accessToken
        )
        return try decoder.decode(String.self, from: data)
    }

    func reserve(listingID: UUID, quantity: Int = 1, accessToken: String) async throws -> BackendReservationResult {
        struct Payload: Encodable {
            let pListingID: UUID
            let pQuantity: Int
        }
        let body = try encoder.encode(Payload(pListingID: listingID, pQuantity: quantity))
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/reserve_listing"),
            method: "POST",
            body: body,
            accessToken: accessToken
        )
        return try decoder.decode(BackendReservationResult.self, from: data)
    }

    /// The signed-in staff member's business settings (today: the bag limit per listing).
    func fetchBusinessSettings(accessToken: String) async throws -> BackendBusinessSettings {
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/get_business_settings"),
            method: "POST",
            body: Data("{}".utf8),
            accessToken: accessToken
        )
        guard let settings = try decoder.decode([BackendBusinessSettings].self, from: data).first else {
            throw BackendError.server("This account isn't staff of a business yet.")
        }
        return settings
    }

    /// Managers only. The database checks the range and returns the saved limit.
    func setMaxBagsPerListing(_ limit: Int, accessToken: String) async throws -> Int {
        let body = try JSONSerialization.data(withJSONObject: ["p_max": limit])
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/set_max_bags_per_listing"),
            method: "POST",
            body: body,
            accessToken: accessToken
        )
        return try decoder.decode(Int.self, from: data)
    }

    /// The signed-in student's Saver Cash, toys, badge counts and league settings.
    func fetchRewards(accessToken: String) async throws -> RemoteRewards {
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/get_my_rewards"),
            method: "POST",
            body: Data("{}".utf8),
            accessToken: accessToken
        )
        return try decoder.decode(RemoteRewards.self, from: data)
    }

    /// `period` is "week" or "all_time".
    func fetchLeague(period: String, accessToken: String) async throws -> RemoteLeague {
        let body = try JSONSerialization.data(withJSONObject: ["p_period": period])
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/get_league"),
            method: "POST",
            body: body,
            accessToken: accessToken
        )
        return try decoder.decode(RemoteLeague.self, from: data)
    }

    /// Joins or leaves the league. The database checks the nickname is 2–20 characters and free.
    func setLeagueProfile(optIn: Bool, nickname: String, accessToken: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["p_opt_in": optIn, "p_nickname": nickname])
        _ = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/set_league_profile"),
            method: "POST",
            body: body,
            accessToken: accessToken
        )
    }

    // MARK: Rewards at the counter (staff)

    /// Reads a student's Saver Cash QR at this kitchen: who it is and their balance.
    func scanRewards(passToken: String, accessToken: String) async throws -> RemoteRewardScan {
        let body = try JSONSerialization.data(withJSONObject: ["p_token": passToken])
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/scan_rewards"),
            method: "POST",
            body: body,
            accessToken: accessToken
        )
        return try decoder.decode(RemoteRewardScan.self, from: data)
    }

    /// Takes Saver Cash off a bill. Reuse `idempotencyKey` when retrying the same bill.
    func redeemSaverCash(passToken: String, amountCents: Int, idempotencyKey: String, accessToken: String) async throws -> RemoteCashRedemption {
        let body = try JSONSerialization.data(withJSONObject: [
            "p_token": passToken,
            "p_amount_cents": amountCents,
            "p_idempotency_key": idempotencyKey
        ])
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/redeem_saver_cash"),
            method: "POST",
            body: body,
            accessToken: accessToken
        )
        return try decoder.decode(RemoteCashRedemption.self, from: data)
    }

    // MARK: Partner rewards (student)

    /// The student uses a partner reward at the shop counter. Returns the one-time code the cashier
    /// sees; using it again returns the same code and time.
    func redeemPartnerReward(rewardID: String, accessToken: String) async throws -> RemotePartnerRedemption {
        let body = try JSONSerialization.data(withJSONObject: ["p_reward_id": rewardID])
        let data = try await request(
            url: BackendConfiguration.projectURL.appending(path: "rest/v1/rpc/redeem_partner_reward"),
            method: "POST",
            body: body,
            accessToken: accessToken
        )
        return try decoder.decode(RemotePartnerRedemption.self, from: data)
    }

    private func request(
        url: URL,
        method: String,
        body: Data? = nil,
        accessToken: String? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(BackendConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? BackendConfiguration.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            // PostgREST's "no such function": the migration that adds it isn't applied yet.
            if payload?["code"] as? String == "PGRST202" { throw BackendError.notDeployed }
            let message = payload?["message"] as? String
                ?? payload?["msg"] as? String
                ?? "KnightSaver service error (\(http.statusCode))."
            throw BackendError.server(message)
        }
        return data
    }
}

