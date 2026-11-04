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

    // 正式 server（VPS docker，nginx + LE HTTPS）
    static let defaultBaseURL = "https://mangotime-api.149-28-154-219.sslip.io"

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

struct MTCalendar: Codable, Identifiable {
    let id: String
    let name: String
    let coverImageUrl: String?
    let creatorId: String
    let memberCount: Int?
    let myRole: String?
}

struct CalendarResponse: Codable { let calendar: MTCalendar }
struct CalendarListResponse: Codable { let calendars: [MTCalendar] }

extension APIClient {
    func listCalendars() async throws -> [MTCalendar] {
        let res: CalendarListResponse = try await request("GET", "/v1/calendars")
        return res.calendars
    }

    func createCalendar(name: String) async throws -> MTCalendar {
        struct Payload: Encodable { let name: String }
        let res: CalendarResponse = try await request("POST", "/v1/calendars", body: Payload(name: name))
        return res.calendar
    }

    func renameCalendar(id: String, name: String) async throws {
        struct Payload: Encodable { let name: String }
        let _: CalendarResponse = try await request("PATCH", "/v1/calendars/\(id)", body: Payload(name: name))
    }

    func deleteCalendar(id: String) async throws {
        struct Empty: Encodable {}
        let _: EmptyResponse = try await request("DELETE", "/v1/calendars/\(id)", body: Optional<Empty>.none)
    }
}

// Type-erasure so any Encodable payload fits the request signature.
struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFn = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}

// MARK: - Events (task 1.4 API)

struct MTEvent: Codable, Identifiable, Hashable {
    let id: String
    let calendarId: String
    let title: String
    let startsAt: String
    let endsAt: String?
    let allDay: Bool
    let repeatRule: String
    let labelColor: String?
    let location: String?
    let url: String?
    let note: String?
}

struct EventResponse: Codable { let event: MTEvent }
struct EventListResponse: Codable { let events: [MTEvent] }

extension APIClient {
    func listEvents(calendarId: String, from: Date, to: Date) async throws -> [MTEvent] {
        let iso = ISO8601DateFormatter()
        let res: EventListResponse = try await request(
            "GET",
            "/v1/calendars/\(calendarId)/events?from=\(iso.string(from: from))&to=\(iso.string(from: to))"
        )
        return res.events
    }

    func createEvent(calendarId: String, title: String, startsAt: Date, allDay: Bool, repeatRule: String, labelColor: String, location: String?, note: String?) async throws -> MTEvent {
        struct Payload: Encodable {
            let title: String
            let startsAt: String
            let allDay: Bool
            let repeatRule: String
            let labelColor: String
            let location: String?
            let note: String?
        }
        let iso = ISO8601DateFormatter()
        let res: EventResponse = try await request(
            "POST", "/v1/calendars/\(calendarId)/events",
            body: Payload(title: title, startsAt: iso.string(from: startsAt), allDay: allDay, repeatRule: repeatRule, labelColor: labelColor, location: location, note: note)
        )
        return res.event
    }

    func deleteEvent(calendarId: String, eventId: String) async throws {
        struct Empty: Encodable {}
        let _: EmptyResponse = try await request("DELETE", "/v1/calendars/\(calendarId)/events/\(eventId)", body: Optional<Empty>.none)
    }
}

func parseISODate(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}
