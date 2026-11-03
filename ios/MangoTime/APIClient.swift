import Foundation

struct MTUser: Codable {
    let id: String
    let email: String
    let displayName: String
    let avatarUrl: String?
}

struct AuthResponse: Codable {
    let user: MTUser
    let token: String
}

struct MeResponse: Codable {
    let user: MTUser
}

enum APIError: LocalizedError {
    case http(Int, String?)
    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return msg ?? "HTTP \(code)"
        }
    }
}

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()

    #if targetEnvironment(simulator)
    static let defaultBaseURL = "http://localhost:8787"
    #else
    static let defaultBaseURL = "http://192.168.0.145:8787"
    #endif

    var baseURL: String
    @Published private(set) var token: String? {
        didSet { UserDefaults.standard.set(token, forKey: "mt_token") }
    }
    @Published var currentUser: MTUser?

    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "mt_base_url") ?? Self.defaultBaseURL
        self.token = UserDefaults.standard.string(forKey: "mt_token")
    }

    private func request<T: Decodable>(_ method: String, _ path: String, body: Encodable? = nil) async throws -> T {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder().encode(AnyEncodable(body)) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError.http(code, msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func register(email: String, password: String, displayName: String) async throws {
        struct Payload: Encodable { let email, password, displayName: String }
        let res: AuthResponse = try await request("POST", "/v1/auth/register", body: Payload(email: email, password: password, displayName: displayName))
        token = res.token
        currentUser = res.user
    }

    func login(email: String, password: String) async throws {
        struct Payload: Encodable { let email, password: String }
        let res: AuthResponse = try await request("POST", "/v1/auth/login", body: Payload(email: email, password: password))
        token = res.token
        currentUser = res.user
    }

    func fetchMe() async throws {
        let res: MeResponse = try await request("GET", "/v1/me")
        currentUser = res.user
    }

    func logout() async {
        struct Empty: Encodable {}
        _ = try? await request("POST", "/v1/auth/logout", body: Optional<Empty>.none) as EmptyResponse
        token = nil
        currentUser = nil
    }
}

struct EmptyResponse: Decodable {}

// Type-erasure so any Encodable payload fits the request signature.
struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFn = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}
