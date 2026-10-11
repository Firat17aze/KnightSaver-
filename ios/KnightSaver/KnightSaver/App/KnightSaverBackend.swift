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
    let id: UUID
    let email: String?
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

enum BackendError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The KnightSaver service returned an unreadable response."
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
            let message = payload?["message"] as? String
                ?? payload?["msg"] as? String
                ?? "KnightSaver service error (\(http.statusCode))."
            throw BackendError.server(message)
        }
        return data
    }
}

