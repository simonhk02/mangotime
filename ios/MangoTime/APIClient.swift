import Foundation

struct MTUser: Codable {
    let id: String
    let email: String
    let displayName: String
    let avatarUrl: String?
    let birthdate: String?
    let digestTime: String?
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

    func request<T: Decodable>(_ method: String, _ path: String, body: Encodable? = nil) async throws -> T {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = method
        if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
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

    // Social 登入（Apple / Google）：成功就 set token + user，同 email 登入一樣
    func loginApple(idToken: String, displayName: String?) async throws {
        struct Payload: Encodable { let idToken: String; let displayName: String? }
        let res: AuthResponse = try await request("POST", "/v1/auth/apple", body: Payload(idToken: idToken, displayName: displayName))
        token = res.token
        currentUser = res.user
    }
    func loginGoogle(idToken: String) async throws {
        struct Payload: Encodable { let idToken: String }
        let res: AuthResponse = try await request("POST", "/v1/auth/google", body: Payload(idToken: idToken))
        token = res.token
        currentUser = res.user
    }

    func fetchMe() async throws {
        let res: MeResponse = try await request("GET", "/v1/me")
        currentUser = res.user
    }

    /// 本地登出（唔 call server——測試用）
    func logoutLocal() {
        token = nil
        currentUser = nil
    }

    func logout() async {
        struct Empty: Encodable {}
        _ = try? await request("POST", "/v1/auth/logout", body: Optional<Empty>.none) as EmptyResponse
        token = nil
        currentUser = nil
    }
}

struct EmptyResponse: Decodable {}

struct MTCalendar: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let coverImageUrl: String?
    let publicSlug: String?
    let creatorId: String
    let memberCount: Int?
    let myRole: String?
    let notify: Bool?
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
    let remindMin: Int?
    let participants: [MTRsvp]?
    let goingCount: Int?
    let memberIds: [String]?
    let pinned: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct MTChild: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let birthdate: String?
}

struct MTBirthday: Codable, Hashable {
    let userId: String
    let displayName: String
    let birthdate: String // "MM-dd"
}

struct MTRsvp: Codable, Hashable {
    let userId: String
    let status: String
    let displayName: String?
}

struct EventResponse: Codable { let event: MTEvent }
struct EventListResponse: Codable { let events: [MTEvent] }
struct AttachmentListResponse: Codable { let attachments: [MTAttachment] }

extension APIClient {
    func uploadCover(calendarId: String, data: Data, mimeType: String) async throws {
        struct P: Encodable { let data: String; let mimeType: String }
        struct R: Codable { let ok: Bool }
        let _: R = try await request("POST", "/v1/calendars/\(calendarId)/cover", body: P(data: data.base64EncodedString(), mimeType: mimeType))
    }
    func markSeen(calendarId: String) async throws {
        struct R: Codable { let ok: Bool }
        let _: R = try await request("POST", "/v1/calendars/\(calendarId)/seen")
    }
    func updateMe(displayName: String? = nil, birthdate: String? = nil, digestTime: String? = nil) async throws {
        struct P: Encodable { let displayName: String?; let birthdate: String?; let digestTime: String? }
        struct R: Codable { let user: MTUser }
        let r: R = try await request("PATCH", "/v1/me", body: P(displayName: displayName, birthdate: birthdate, digestTime: digestTime))
        currentUser = r.user
    }
    func listChildren(calendarId: String) async throws -> [MTChild] {
        struct R: Codable { let children: [MTChild] }
        let res: R = try await request("GET", "/v1/calendars/\(calendarId)/children")
        return res.children
    }
    func addChild(calendarId: String, name: String, birthdate: String? = nil) async throws {
        struct P: Encodable { let name: String; let birthdate: String? }
        struct R: Codable { let child: MTChild }
        let _: R = try await request("POST", "/v1/calendars/\(calendarId)/children", body: P(name: name, birthdate: birthdate))
    }
    func removeChild(calendarId: String, childId: String) async throws {
        let _: EmptyResponse = try await request("DELETE", "/v1/calendars/\(calendarId)/children/\(childId)")
    }

    func listBirthdays(calendarId: String) async throws -> [MTBirthday] {
        struct R: Codable { let birthdays: [MTBirthday] }
        let res: R = try await request("GET", "/v1/calendars/\(calendarId)/birthdays")
        return res.birthdays
    }

    func reorderCalendars(ids: [String]) async throws {
        struct P: Encodable { let ids: [String] }
        struct R: Codable { let ok: Bool }
        let _: R = try await request("PATCH", "/v1/calendars/order", body: P(ids: ids))
    }
    func setCalendarNotify(calendarId: String, notify: Bool) async throws {
        struct P: Encodable { let notify: Bool }
        struct R: Codable { let ok: Bool }
        let _: R = try await request("PATCH", "/v1/calendars/\(calendarId)/notify", body: P(notify: notify))
    }

    func setRsvp(eventId: String, status: String) async throws {
        struct P: Encodable { let status: String }
        let _: [String: Bool] = try await request("POST", "/v1/events/\(eventId)/rsvp", body: P(status: status))
    }
    func clearRsvp(eventId: String) async throws {
        let _: [String: Bool] = try await request("DELETE", "/v1/events/\(eventId)/rsvp")
    }
}

extension APIClient {
    func listEvents(calendarId: String, from: Date, to: Date) async throws -> [MTEvent] {
        let iso = ISO8601DateFormatter()
        let res: EventListResponse = try await request(
            "GET",
            "/v1/calendars/\(calendarId)/events?from=\(iso.string(from: from))&to=\(iso.string(from: to))"
        )
        return res.events
    }

    func createEvent(calendarId: String, title: String, startsAt: Date, allDay: Bool, repeatRule: String, labelColor: String, location: String?, note: String?, remindMin: Int? = nil, memberIds: [String]? = nil, pinned: Bool? = nil) async throws -> MTEvent {
        struct Payload: Encodable {
            let title: String
            let startsAt: String
            let allDay: Bool
            let repeatRule: String
            let labelColor: String
            let location: String?
            let note: String?
            let remindMin: Int?
            let memberIds: [String]?
            let pinned: Bool?
        }
        let iso = ISO8601DateFormatter()
        let res: EventResponse = try await request(
            "POST", "/v1/calendars/\(calendarId)/events",
            body: Payload(title: title, startsAt: iso.string(from: startsAt), allDay: allDay, repeatRule: repeatRule, labelColor: labelColor, location: location, note: note, remindMin: remindMin, memberIds: memberIds, pinned: pinned)
        )
        return res.event
    }

    func deleteEvent(calendarId: String, eventId: String) async throws {
        struct Empty: Encodable {}
        let _: EmptyResponse = try await request("DELETE", "/v1/calendars/\(calendarId)/events/\(eventId)", body: Optional<Empty>.none)
    }

    func updateEvent(eventId: String, title: String?, startsAt: Date?, allDay: Bool?, labelColor: String?, location: String?, note: String?, remindMin: Int? = nil, memberIds: [String]? = nil, pinned: Bool? = nil) async throws -> MTEvent {
        struct Payload: Encodable {
            let title: String?
            let startsAt: String?
            let allDay: Bool?
            let labelColor: String?
            let location: String?
            let note: String?
            let remindMin: Int?
            let memberIds: [String]?
            let pinned: Bool?
        }
        let iso = ISO8601DateFormatter()
        let res: EventResponse = try await request(
            "PATCH", "/v1/events/\(eventId)",
            body: Payload(title: title, startsAt: startsAt.map { iso.string(from: $0) }, allDay: allDay, labelColor: labelColor, location: location, note: note, remindMin: remindMin, memberIds: memberIds, pinned: pinned)
        )
        return res.event
    }
}

// MARK: - Invites & members (task 1.3)

struct MTInvite: Codable { let code: String }
struct MTInvitePreview: Codable { let code: String; let calendarName: String; let memberCount: Int }
struct MTInviteWrap: Codable { let invite: MTInvite }
struct MTInvitePreviewWrap: Codable { let invite: MTInvitePreview }
struct MTAcceptResult: Codable { let calendarId: String; let alreadyMember: Bool }
struct MTMember: Codable, Identifiable {
    let userId: String
    let role: String
    let color: String?
    let lastSeenAt: String?
    let displayName: String
    let email: String
    let avatarUrl: String?
    var id: String { userId }
}
struct MTMemberList: Codable { let members: [MTMember] }

extension APIClient {
    func createInvite(calendarId: String) async throws -> MTInvite {
        struct Empty: Encodable {}
        let res: MTInviteWrap = try await request("POST", "/v1/calendars/\(calendarId)/invites", body: Optional<Empty>.none)
        return res.invite
    }
    func previewInvite(code: String) async throws -> MTInvitePreview {
        let res: MTInvitePreviewWrap = try await request("GET", "/v1/invites/\(code)")
        return res.invite
    }
    func acceptInvite(code: String) async throws -> MTAcceptResult {
        struct Empty: Encodable {}
        return try await request("POST", "/v1/invites/\(code)/accept", body: Optional<Empty>.none)
    }
    func listMembers(calendarId: String) async throws -> [MTMember] {
        let res: MTMemberList = try await request("GET", "/v1/calendars/\(calendarId)/members")
        return res.members
    }
    func setMemberColor(calendarId: String, userId: String, color: String?) async throws {
        struct P: Encodable { let color: String? }
        struct R: Codable { let ok: Bool }
        let _: R = try await request("PATCH", "/v1/calendars/\(calendarId)/members/\(userId)/color", body: P(color: color))
    }
    func removeMember(calendarId: String, userId: String) async throws {
        let _: EmptyResponse = try await request("DELETE", "/v1/calendars/\(calendarId)/members/\(userId)")
    }
}

// MARK: - Comments (task 2.1)

struct MTComment: Codable, Identifiable {
    let id: String
    let body: String
    let createdAt: String
    let authorId: String
    let authorName: String
    let authorAvatar: String?
}
struct MTCommentWrap: Codable { let comment: MTComment }
struct MTCommentList: Codable { let comments: [MTComment] }

extension APIClient {
    func listComments(eventId: String) async throws -> [MTComment] {
        let res: MTCommentList = try await request("GET", "/v1/events/\(eventId)/comments")
        return res.comments
    }
    func postComment(eventId: String, body: String) async throws -> MTComment {
        struct Payload: Encodable { let body: String }
        let res: MTCommentWrap = try await request("POST", "/v1/events/\(eventId)/comments", body: Payload(body: body))
        return res.comment
    }
}

// MARK: - Memos (task 2.2)

struct MTMemo: Codable, Identifiable, Hashable {
    let id: String
    let calendarId: String
    let title: String
    let body: String
    let labelColor: String?
    let creatorId: String
    let updatedAt: String
    let commentCount: Int?
}
struct MTMemoWrap: Codable { let memo: MTMemo }
struct MTMemoList: Codable { let memos: [MTMemo] }

extension APIClient {
    func listMemos(calendarId: String) async throws -> [MTMemo] {
        let res: MTMemoList = try await request("GET", "/v1/calendars/\(calendarId)/memos")
        return res.memos
    }
    func createMemo(calendarId: String, title: String, body: String) async throws -> MTMemo {
        struct Payload: Encodable { let title, body: String }
        let res: MTMemoWrap = try await request("POST", "/v1/calendars/\(calendarId)/memos", body: Payload(title: title, body: body))
        return res.memo
    }
    func deleteMemo(id: String) async throws {
        struct Empty: Encodable {}
        let _: EmptyResponse = try await request("DELETE", "/v1/memos/\(id)", body: Optional<Empty>.none)
    }
    func listMemoComments(memoId: String) async throws -> [MTComment] {
        let res: MTCommentList = try await request("GET", "/v1/memos/\(memoId)/comments")
        return res.comments
    }
    func postMemoComment(memoId: String, body: String) async throws -> MTComment {
        struct Payload: Encodable { let body: String }
        let res: MTCommentWrap = try await request("POST", "/v1/memos/\(memoId)/comments", body: Payload(body: body))
        return res.comment
    }
}

// MARK: - Todos (task 2.3)

struct MTTodoItem: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let done: Bool
}
struct MTTodoList: Codable, Identifiable, Hashable {
    let id: String
    let calendarId: String
    let title: String
    let total: Int
    let done: Int
    let items: [MTTodoItem]
}
struct MTTodoListWrap: Codable { let list: MTTodoList }
struct MTTodoListsWrap: Codable { let lists: [MTTodoList] }
struct MTTodoItemWrap: Codable { let item: MTTodoItem }

extension APIClient {
    func listTodos(calendarId: String) async throws -> [MTTodoList] {
        let res: MTTodoListsWrap = try await request("GET", "/v1/calendars/\(calendarId)/todos")
        return res.lists
    }
    func createTodoList(calendarId: String, title: String) async throws -> MTTodoList {
        struct Payload: Encodable { let title: String }
        let res: MTTodoListWrap = try await request("POST", "/v1/calendars/\(calendarId)/todos", body: Payload(title: title))
        return res.list
    }
    func addTodoItem(listId: String, text: String) async throws -> MTTodoItem {
        struct Payload: Encodable { let text: String }
        let res: MTTodoItemWrap = try await request("POST", "/v1/todos/\(listId)/items", body: Payload(text: text))
        return res.item
    }
    func toggleTodoItem(itemId: String, done: Bool) async throws {
        struct Payload: Encodable { let done: Bool }
        let _: MTTodoItemWrap = try await request("PATCH", "/v1/todo-items/\(itemId)", body: Payload(done: done))
    }
    func deleteTodoList(id: String) async throws {
        struct Empty: Encodable {}
        let _: EmptyResponse = try await request("DELETE", "/v1/todos/\(id)", body: Optional<Empty>.none)
    }
}

// MARK: - Photos (task 2.4)

struct MTPhoto: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let mimeType: String
    let size: Int
    let uploaderId: String
    let uploaderName: String
}
struct MTPhotoWrap: Codable { let photo: MTPhoto }
struct MTPhotoList: Codable { let photos: [MTPhoto] }

extension APIClient {
    func listPhotos(calendarId: String) async throws -> [MTPhoto] {
        let res: MTPhotoList = try await request("GET", "/v1/calendars/\(calendarId)/photos")
        return res.photos
    }
    func uploadPhoto(calendarId: String, data: Data, mimeType: String) async throws -> MTPhoto {
        struct Payload: Encodable { let data, mimeType: String }
        let res: MTPhotoWrap = try await request(
            "POST", "/v1/calendars/\(calendarId)/photos",
            body: Payload(data: data.base64EncodedString(), mimeType: mimeType)
        )
        return res.photo
    }
    func deletePhoto(id: String) async throws {
        struct Empty: Encodable {}
        let _: EmptyResponse = try await request("DELETE", "/v1/photos/\(id)", body: Optional<Empty>.none)
    }
    func fileURL(_ path: String) -> URL? { URL(string: baseURL + path) }
}

// MARK: - Activity (task 2.5)

struct MTAttachment: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let mimeType: String
    let size: Int
    let uploaderId: String
    let uploaderName: String
    let createdAt: String
}

struct MTActivity: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let icon: String
    let text: String
    let actorId: String?
    let actorName: String
    let createdAt: String
}
struct MTActivityWrap: Codable { let items: [MTActivity] }

extension APIClient {
    func listActivity(calendarId: String) async throws -> [MTActivity] {
        let res: MTActivityWrap = try await request("GET", "/v1/calendars/\(calendarId)/activity")
        return res.items
    }
    func listNotices() async throws -> [MTNotice] {
        let res: MTNoticeWrap = try await request("GET", "/v1/notices")
        return res.notices
    }
    func searchEvents(calendarId: String, q: String) async throws -> [MTEvent] {
        let res: EventListResponse = try await request("GET", "/v1/calendars/\(calendarId)/events/search?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)")
        return res.events
    }
    func enablePublic(calendarId: String) async throws -> String {
        struct R: Codable { let publicSlug: String }
        struct Empty: Encodable {}
        let res: R = try await request("POST", "/v1/calendars/\(calendarId)/public", body: Optional<Empty>.none)
        return res.publicSlug
    }
    func listAttachments(eventId: String) async throws -> [MTAttachment] {
        let res: AttachmentListResponse = try await request("GET", "/v1/events/\(eventId)/attachments")
        return res.attachments
    }
    func uploadAttachment(eventId: String, data: Data, mimeType: String) async throws {
        struct Req: Encodable { let data: String; let mimeType: String }
        struct Res: Codable { let attachment: MTAttachment }
        let _: Res = try await request("POST", "/v1/events/\(eventId)/attachments", body: Req(data: data.base64EncodedString(), mimeType: mimeType))
    }
    // 5.1 外曆訂閱
    func subscribeExternal(calendarId: String, url: String, name: String?) async throws {
        struct Req: Encodable { let url: String; let name: String? }
        struct Res: Codable { let external: MTExternal }
        let _: Res = try await request("POST", "/v1/calendars/\(calendarId)/externals", body: Req(url: url, name: name))
    }
    func listExternalEvents(calendarId: String) async throws -> [MTExternalEvent] {
        struct Res: Codable { let events: [MTExternalEvent] }
        let res: Res = try await request("GET", "/v1/calendars/\(calendarId)/externals/events")
        return res.events
    }
    // 5.3 Event Scan
    func scanImage(calendarId: String, data: Data, mimeType: String) async throws -> [MTScannedEvent] {
        struct Req: Encodable { let data: String; let mimeType: String }
        struct Res: Codable { let events: [MTScannedEvent] }
        let res: Res = try await request("POST", "/v1/calendars/\(calendarId)/scan", body: Req(data: data.base64EncodedString(), mimeType: mimeType))
        return res.events
    }
    // APNs：註冊 device token
    func registerDevice(token: String) async throws {
        struct Req: Encodable { let token: String; let platform: String }
        struct Res: Codable { let ok: Bool }
        let _: Res = try await request("POST", "/v1/devices", body: Req(token: token, platform: "ios"))
    }
    // 5.5 iCal
    func exportIcs(calendarId: String) async throws -> Data {
        guard let token else { throw APIError.http(401, "未登入") }
        var req = URLRequest(url: URL(string: "\(baseURL)/v1/calendars/\(calendarId)/export.ics")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await URLSession.shared.data(for: req)
        guard (res as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.http(500, "匯出失敗") }
        return data
    }
    func importIcs(calendarId: String, ics: String) async throws -> Int {
        struct Req: Encodable { let ics: String }
        struct Res: Codable { let imported: Int }
        let res: Res = try await request("POST", "/v1/calendars/\(calendarId)/import", body: Req(ics: ics))
        return res.imported
    }
}

struct MTScannedEvent: Codable, Identifiable, Hashable {
    var id: String { title + date + (time ?? "") }
    let title: String
    let date: String
    let time: String?
    let location: String?
    let note: String?
}

// MARK: - External calendars (task 5.1)

struct MTExternal: Codable, Identifiable {
    let id: String
    let url: String
    let name: String
}

struct MTExternalEvent: Codable, Identifiable, Hashable {
    var id: String { uid + externalId }
    let uid: String
    let title: String
    let startsAt: String
    let endsAt: String?
    let allDay: Bool
    let repeatRule: String
    let sourceName: String
    let externalId: String
}

struct MTNotice: Codable, Identifiable, Hashable {
    let id: String
    let calendarId: String
    let actorName: String
    let text: String
    let createdAt: String
}
struct MTNoticeWrap: Codable { let notices: [MTNotice] }

func parseISODate(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}
