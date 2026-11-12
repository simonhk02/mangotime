import SwiftUI
import AuthenticationServices
import WidgetKit

/// ASWebAuthenticationSession 要個 presentation anchor
final class GoogleAuthContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuthContext()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

/// 收鍵盤（submit 之後叫——唔係鍵盤會遮住底部 tab bar）
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// 原型全域狀態 + 根視圖（splash → login → tab app）
enum ProtoScreen: Hashable {
    case splash, login
    case month, weekly
    case calendarList, monthPicker
    case calendarSettings(MTCalendar)
    case create, noteEdit
    case editEvent(MTEvent)
    case eventDetail(MockEvent)
    case liveEventDetail(MTEvent)
    case search
    case feed, notices, other, profile
    case memos, memosEmpty, memoDetail(MockMemo), liveMemoDetail(MTMemo)
    case todos, album, members, invite
    case extSubscribe
    case availability
    case settings, displaySettings, filterSettings, displayCalendar, widgetCalendar, notifSettings
    case noticeBoard, noticeDetail
    case premium, premiumDetail
    case helpHome, helpCategory(HelpCat), helpArticle(String), faq, contact, userGuide
}

final class ProtoState: ObservableObject {
    @Published var screen: ProtoScreen = .splash
    @Published var lunarOn = true
    @Published var weekStartMonday = true
    @Published var weekNumbersOn = UserDefaults.standard.bool(forKey: "week_numbers") { didSet { UserDefaults.standard.set(weekNumbersOn, forKey: "week_numbers") } }
    @Published var holidaysOn = UserDefaults.standard.bool(forKey: "holidays_on") { didSet { UserDefaults.standard.set(holidaysOn, forKey: "holidays_on") } }
    @Published var hour24 = UserDefaults.standard.object(forKey: "hour24") == nil ? true : UserDefaults.standard.bool(forKey: "hour24") { didSet { UserDefaults.standard.set(hour24, forKey: "hour24") } }
    @Published var fontSizeIdx = UserDefaults.standard.integer(forKey: "font_size_idx") { didSet { UserDefaults.standard.set(fontSizeIdx, forKey: "font_size_idx") } } // 0=小 1=中 2=大
    @Published var hiddenCalendarIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "hidden_cals") ?? []) { didSet { UserDefaults.standard.set(Array(hiddenCalendarIds), forKey: "hidden_cals") } }
    @Published var settingsTab = 0 // 0=設定 1=支援
    @Published var feedTab = 0 // 0=行程 1=相簿
    @Published var toast = ""
    @Published var upsell = false
    @Published var photoPerm = false

    // LIVE 模式（api != nil）：月曆/行事曆/活動用真 server data，其餘畫面暫時 mock
    var api: APIClient? {
        didSet { if let api { premium.attach(api) } }
    }
    let premium = PremiumManager()
    @Published var liveCalendars: [MTCalendar] = []
    @Published var liveEvents: [MTEvent] = []
    @Published var activeCalendarId: String?
    @Published var loginError: String?
    @Published var liveMembers: [MTMember] = []
    @Published var inviteCode: String?
    @Published var liveExternalEvents: [MTExternalEvent] = []
    @Published var liveBirthdays: [MTBirthday] = []
    @Published var displayMonth = Date() // 月曆而家顯示緊邊個月（‹ › 導航）
    var duplicateSource: MTEvent? // 「複製活動」來源（入 create 頁 prefill 用，用完即清）

    // widget 顯示邊個曆（nil = 跟 active）
    @Published var widgetCalendarId: String? = UserDefaults.standard.string(forKey: "widget_cal") {
        didSet { UserDefaults.standard.set(widgetCalendarId, forKey: "widget_cal"); Task { @MainActor in self.syncWidget() } }
    }

    // 「！」離線暫存：開活動失敗（冇網）→ 本機 queue，有網補發
    @Published var pendingCount = UserDefaults.standard.integer(forKey: "pending_events_n")
    private var pendingEvents: [[String: String]] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "pending_events"),
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return [] }
            return arr
        }
        set {
            UserDefaults.standard.set(try? JSONSerialization.data(withJSONObject: newValue), forKey: "pending_events")
            pendingCount = newValue.count
        }
    }
    func stashEvent(title: String, iso: String, allDay: Bool, labelColor: String) {
        var q = pendingEvents
        q.append(["title": title, "startsAt": iso, "allDay": allDay ? "1" : "0", "labelColor": labelColor])
        pendingEvents = q
    }
    /// 有網嗰陣補發
    func flushPending() async {
        guard let api, let calId = activeCalendarId else { return }
        var q = pendingEvents
        var flushed = 0
        while let first = q.first {
            guard let d = parseISODate(first["startsAt"] ?? "") else { q.removeFirst(); continue }
            do {
                _ = try await api.createEvent(calendarId: calId, title: first["title"] ?? "", startsAt: d, allDay: first["allDay"] == "1", repeatRule: "none", labelColor: first["labelColor"] ?? "bright-orange", location: nil, note: nil)
                q.removeFirst()
                flushed += 1
            } catch { break } // 仲係冇網——留返下次
        }
        pendingEvents = q
        if flushed > 0 { note("補發咗 \(flushed) 個離線活動 ✓") }
    }

    // NEW 未讀標記：per-calendar 最後查看時間（本機儲存）
    private var lastSeen: [String: Double] {
        get { (UserDefaults.standard.dictionary(forKey: "cal_seen") as? [String: Double]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "cal_seen") }
    }
    func markCalendarSeen(_ calId: String) {
        var m = lastSeen; m[calId] = Date().timeIntervalSince1970; lastSeen = m
    }
    /// 個曆有冇我未睇過嘅活動更新（updatedAt > 上次 mark）
    func calendarHasUnseen(_ cal: MTCalendar) -> Bool {
        guard let seen = lastSeen[cal.id] else { return false } // 從未睇過唔當 NEW（第一次入 app 全部係新）
        return liveEvents.contains { ev in
            ev.calendarId == cal.id && (parseISODate(ev.updatedAt ?? ev.createdAt ?? "")?.timeIntervalSince1970 ?? 0) > seen
        }
    }
    // 篩選：空 set = 全部顯示；有值 = 淨顯示嗰啲 label 色
    @Published var filterLabels: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "filter_labels") ?? []) {
        didSet { UserDefaults.standard.set(Array(filterLabels), forKey: "filter_labels") }
    }

    @MainActor
    func loadMembers() async {
        guard let api, let calId = activeCalendarId else { return }
        liveMembers = (try? await api.listMembers(calendarId: calId)) ?? []
    }

    @MainActor
    func loadInvite() async {
        guard let api, let calId = activeCalendarId else { return }
        inviteCode = try? await api.createInvite(calendarId: calId).code
    }

    @MainActor
    func joinByCode(_ code: String) async -> String? {
        guard let api else { return "未連接" }
        do {
            _ = try await api.acceptInvite(code: code)
            await loadLive()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    func loadLive(month: Date? = nil) async {
        guard let api else { return }
        do {
            liveCalendars = try await api.listCalendars()
            await flushPending()
            if activeCalendarId == nil { activeCalendarId = liveCalendars.first?.id }
            if let calId = activeCalendarId {
                let cal = Calendar(identifier: .gregorian)
                let comps = cal.dateComponents([.year, .month], from: month ?? displayMonth)
                let from = cal.date(from: comps)!
                let to = cal.date(byAdding: .month, value: 1, to: from)!
                liveEvents = try await api.listEvents(calendarId: calId, from: from, to: to)
                liveExternalEvents = (try? await api.listExternalEvents(calendarId: calId)) ?? []
                liveBirthdays = (try? await api.listBirthdays(calendarId: calId)) ?? []
                syncWidget()
                // 「查看過」server 端記錄（對方最後查看時間用）
                try? await api.markSeen(calendarId: calId)
                markCalendarSeen(calId)
            }
        } catch {
            note("載入失敗：\(error.localizedDescription)")
        }
    }

    /// Widget 快取：今日活動寫落 App Group（widget 15 分鐘讀一次）
    @MainActor
    func syncWidget() {
        // 揀咗其他曆 → 額外 fetch 佢今日活動
        if let wid = widgetCalendarId, wid != activeCalendarId, let api {
            Task {
                let cal = Calendar(identifier: .gregorian)
                let from = cal.startOfDay(for: Date())
                let to = cal.date(byAdding: .day, value: 1, to: from)!
                let evs = (try? await api.listEvents(calendarId: wid, from: from, to: to)) ?? []
                writeWidget(events: evs, calendarName: liveCalendars.first(where: { $0.id == wid })?.name ?? "MangoTime")
            }
            return
        }
        writeWidget(events: liveEvents, calendarName: liveCalendars.first(where: { $0.id == activeCalendarId })?.name ?? "MangoTime")
    }

    private func writeWidget(events: [MTEvent], calendarName: String) {
        let cal = Calendar(identifier: .gregorian)
        let todayEvents = events.compactMap { ev -> [String: String]? in
            guard let start = parseISODate(ev.startsAt), cal.isDateInToday(start) else { return nil }
            let timeStr: String
            if ev.allDay { timeStr = "全日" } else {
                let f = DateFormatter(); f.dateFormat = "HH:mm"; timeStr = f.string(from: start)
            }
            return ["id": ev.id, "title": ev.title, "time": timeStr, "colorHex": colorHex(ev.labelColor)]
        }
        let snap: [String: Any] = [
            "calendarName": calendarName,
            "events": todayEvents,
            "updatedAt": Date().timeIntervalSince1970,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: snap) {
            UserDefaults(suiteName: "group.com.mangotime.app")?.set(data, forKey: "widget_today")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func colorHex(_ key: String?) -> String {
        switch key {
        case "emerald": return "#10B981"
        case "blue": return "#3B82F6"
        case "red": return "#EF4444"
        case "purple": return "#A855F7"
        default: return "#FF7043"
        }
    }

    @MainActor
    func createLiveEvent(title: String, date: Date, allDay: Bool, labelColor: String, location: String?, noteText: String?, repeatRule: String, remindMin: Int? = nil, memberIds: [String]? = nil) async {
        guard let api, let calId = activeCalendarId else { return }
        do {
            _ = try await api.createEvent(calendarId: calId, title: title, startsAt: date, allDay: allDay, repeatRule: repeatRule, labelColor: labelColor, location: location, note: noteText, remindMin: remindMin, memberIds: memberIds)
            note("已保存 ✓")
            await loadLive()
            screen = .month
        } catch {
            note("保存失敗：\(error.localizedDescription)")
        }
    }

    @MainActor
    func createLiveCalendar(name: String) async {
        guard let api else { return }
        do {
            let cal = try await api.createCalendar(name: name)
            activeCalendarId = cal.id
            await loadLive()
            note("已開行事曆 ✓")
        } catch {
            note("失敗：\(error.localizedDescription)")
        }
    }

    @MainActor
    func deleteLiveEvent(_ ev: MTEvent) async {
        guard let api else { return }
        do {
            try await api.deleteEvent(calendarId: ev.calendarId, eventId: ev.id)
            note("已刪除 ✓")
            await loadLive()
            screen = .month
        } catch {
            note("刪除失敗：\(error.localizedDescription)")
        }
    }

    init() {
        // 驗證用：launch argument `-screen <name>` 直達指定畫面（cap 圖對照參考圖）
        let args = ProcessInfo.processInfo.arguments
        func arg(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let v = arg("-lunar") { lunarOn = v != "0" }
        if let v = arg("-settingstab") { settingsTab = Int(v) ?? 0 }
        if let v = arg("-feedtab") { feedTab = Int(v) ?? 0 }
        if let v = arg("-upsell") { upsell = v == "1" }
        if let v = arg("-photoperm") { photoPerm = v == "1" }
        if let name = arg("-screen") {
            screen = ProtoState.screenByName(name)
        }
    }

    static func screenByName(_ name: String) -> ProtoScreen {
        switch name {
        case "login": return .login
        case "month": return .month
        case "weekly": return .weekly
        case "calendarList": return .calendarList
        case "monthPicker": return .monthPicker
        case "create": return .create
        case "noteEdit": return .noteEdit
        case "eventDetail": return .eventDetail(Mock.events[0])
        case "search": return .search
        case "feed": return .feed
        case "notices": return .notices
        case "other": return .other
        case "profile": return .profile
        case "memos": return .memos
        case "memosEmpty": return .memosEmpty
        case "memoDetail": return .memoDetail(Mock.memos[0])
        case "todos": return .todos
        case "album": return .album
        case "members": return .members
        case "invite": return .invite
        case "settings": return .settings
        case "displaySettings": return .displaySettings
        case "filterSettings": return .filterSettings
        case "displayCalendar": return .displayCalendar
        case "notifSettings": return .notifSettings
        case "noticeBoard": return .noticeBoard
        case "noticeDetail": return .noticeDetail
        case "premium": return .premium
        case "premiumDetail": return .premiumDetail
        case "helpHome": return .helpHome
        case "helpCategory": return .helpCategory(Mock.helpCats[1])
        case "helpArticle": return .helpArticle("因變更機型而希望繼承數據")
        case "faq": return .faq
        case "contact": return .contact
        case "userGuide": return .userGuide
        default: return .splash
        }
    }

    func note(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in self?.toast = "" }
    }
}

struct ProtoRootView: View {
    @StateObject private var s = ProtoState()
    var live: Bool = false

    var body: some View {
        // 注意：唔好用 ZStack root——會破壞 SwiftUI 鍵盤避讓（輸入位俾鍵盤遮，UAT 真撳捉到）
        Group {
            switch s.screen {
            case .splash: SplashView()
            case .login: ProtoLoginView()
            default:
                VStack(spacing: 0) {
                    ProtoContent()
                    Spacer(minLength: 0)
                    if [.month, .weekly, .feed, .notices, .other].contains(s.screen) {
                        ProtoTabBar()
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if !s.toast.isEmpty {
                Text(s.toast)
                    .font(.footnote).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color(.label).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 50)
                    .transition(.opacity)
            }
        }
        .overlay { if s.upsell { PremiumUpsell() } }
        .overlay { if s.photoPerm { PhotoPermAlert() } }
        // 字體大小全 app 生效（dynamicTypeSize：小/中/大）
        .dynamicTypeSize(s.fontSizeIdx == 0 ? .small : (s.fontSizeIdx == 2 ? .xxLarge : .medium))
        .environmentObject(s)
        .animation(.easeInOut(duration: 0.2), value: s.screen)
        .onAppear {
            guard live, s.api == nil else { return }
            s.api = APIClient.shared
            // 測試用：`-fresh` 清 token 由登入頁開始
            if ProcessInfo.processInfo.arguments.contains("-fresh") {
                UserDefaults.standard.removeObject(forKey: "mt_token")
                UserDefaults.standard.removeObject(forKey: "mt_base_url")
                APIClient.shared.logoutLocal()
            }
            if APIClient.shared.token != nil {
                s.screen = .month
                Task { await s.loadLive() }
            } else {
                s.screen = .login
            }
        }
    }
}

struct SplashView: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        Button { withAnimation(.easeInOut(duration: 0.25)) { s.screen = .login } } label: {
            VStack(spacing: 12) {
                Spacer()
                MangoLogo(size: 88)
                Text("MangoTime").font(.largeTitle).bold()
                Text("一齊夾時間").foregroundStyle(PT.soft)
                Spacer()
                Text("撳任何地方開始 ›").font(.footnote).foregroundStyle(PT.soft)
                    .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}

struct ProtoLoginView: View {
    @EnvironmentObject var s: ProtoState
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var registerMode = false
    @State private var busy = false

    /// Google 登入：ASWebAuthenticationSession 開 Google OAuth（response_type=id_token）
    /// redirect 用 reversed client id scheme（Info.plist 已註冊）
    private func startGoogleLogin() {
        let clientId = "289476107711-c10sn778dm17eg68aghaoae9j9i0d3e0.apps.googleusercontent.com"
        let scheme = "com.googleusercontent.apps.289476107711-c10sn778dm17eg68aghaoae9j9i0d3e0"
        let nonce = UUID().uuidString
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: "\(scheme):/oauth2redirect"),
            .init(name: "response_type", value: "id_token"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "nonce", value: nonce),
        ]
        guard let url = comps.url else { return }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
            guard error == nil, let callbackURL else { return }
            // callback fragment: #id_token=...&...
            guard let fragment = callbackURL.fragment,
                  let pair = fragment.split(separator: "&").first(where: { $0.hasPrefix("id_token=") }) else { return }
            let idToken = String(pair.dropFirst("id_token=".count))
            Task { @MainActor in
                do {
                    try await s.api?.loginGoogle(idToken: idToken)
                    s.screen = .month
                    await s.loadLive()
                } catch {
                    s.loginError = error.localizedDescription
                }
            }
        }
        session.presentationContextProvider = GoogleAuthContext.shared
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            MangoLogo(size: 64)
            Text("MangoTime").font(.largeTitle).bold()
            Text("一齊夾時間，一家人一個曆").font(.subheadline).foregroundStyle(PT.soft)
            if registerMode {
                TextField("名稱", text: $name).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("reg_name")
            }
            TextField("電郵", text: $email).textFieldStyle(.roundedBorder).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("login_email")
            SecureField("密碼", text: $password).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("login_password")
            if !password.isEmpty && password.count < 8 {
                Text("密碼最少 8 位（而家 \(password.count) 位）")
                    .font(.caption).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !email.isEmpty && !email.contains("@") {
                Text("電郵格式唔啱")
                    .font(.caption).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = s.loginError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            Button {
                hideKeyboard()
                busy = true
                s.loginError = nil
                Task {
                    defer { busy = false }
                    do {
                        if registerMode {
                            try await s.api?.register(email: email, password: password, displayName: name.isEmpty ? email : name)
                        } else {
                            try await s.api?.login(email: email, password: password)
                        }
                        s.screen = .month
                        await s.loadLive()
                    } catch {
                        s.loginError = error.localizedDescription
                    }
                }
            } label: {
                Text(busy ? "…" : (registerMode ? "註冊" : "登入")).bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(busy || email.isEmpty || password.count < 8)
            if s.api == nil {
                // mock 模式：撳就入
                Button("未有帳號？註冊") { s.screen = .month }.foregroundStyle(PT.orange)
                Text("或").font(.caption).foregroundStyle(PT.soft)
                Button { s.screen = .month } label: {
                    Label("使用 Apple 登入", systemImage: "applelogo")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                }
                Button { s.screen = .month } label: {
                    Text("G 使用 Google 登入")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                }
                .foregroundStyle(.primary)
            } else {
                Button(registerMode ? "已經有帳號？登入" : "未有帳號？註冊") {
                    registerMode.toggle(); s.loginError = nil
                }
                .foregroundStyle(PT.orange)
                Text("或").font(.caption).foregroundStyle(PT.soft)
                // Apple 登入（真）：Sign in with Apple → identityToken → server 驗簽
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                              let tokenData = cred.identityToken,
                              let idToken = String(data: tokenData, encoding: .utf8) else {
                            s.loginError = "攞唔到 Apple 登入憑證"; return
                        }
                        // Apple 淨係第一次俾名/email，組埋送去 server 記住
                        let full = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                        busy = true
                        Task {
                            defer { busy = false }
                            do {
                                try await s.api?.loginApple(idToken: idToken, displayName: full.isEmpty ? nil : full)
                                s.screen = .month
                                await s.loadLive()
                            } catch {
                                s.loginError = error.localizedDescription
                            }
                        }
                    case .failure(let err):
                        if (err as NSError).code != ASAuthorizationError.canceled.rawValue {
                            s.loginError = err.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                // Google 登入（真）：ASWebAuthenticationSession 開 Google OAuth → idToken → server
                Button {
                    startGoogleLogin()
                } label: {
                    HStack(spacing: 8) {
                        Text("G").font(.headline).bold()
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                        Text("使用 Google 登入").foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct ProtoTabBar: View {
    @EnvironmentObject var s: ProtoState
    func tab(_ icon: String, _ label: String, _ target: ProtoScreen, _ active: Bool, _ id: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { s.screen = target } } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 10))
            }
            .foregroundStyle(active ? PT.orange : PT.soft)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
    }
    var body: some View {
        HStack(alignment: .bottom) {
            tab("calendar", "行事曆", .month, s.screen == .month || s.screen == .weekly, "tab_calendar")
            tab("newspaper", "最新動態", .feed, s.screen == .feed, "tab_feed")
            Button { withAnimation(.easeInOut(duration: 0.18)) { s.screen = .create } } label: {
                Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 50, height: 50).background(PT.orange).clipShape(Circle())
                    .shadow(color: PT.orange.opacity(0.4), radius: 6, y: 3)
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("tab_plus")
            .accessibilityLabel("新增")
            tab("bell", "通知", .notices, s.screen == .notices, "tab_notices")
            tab("line.3.horizontal", "其他", .other, s.screen == .other, "tab_other")
        }
        .padding(.top, 6).padding(.bottom, 4)
        .background(.bar)
    }
}

struct ProtoContent: View {
    @EnvironmentObject var s: ProtoState
    @State private var navStyle: NavStyle = .push

    private enum NavStyle { case tab, sheet, push }

    private static let tabScreens: Set<ProtoScreen> = [.month, .weekly, .feed, .notices, .other]

    private func styleFor(from old: ProtoScreen, to new: ProtoScreen) -> NavStyle {
        // 新增/編輯活動 = iOS sheet 式由下面彈上
        if case .create = new { return .sheet }
        if case .editEvent = new { return .sheet }
        // tab 互轉 = 淡入淡出
        if ProtoContent.tabScreens.contains(old) && ProtoContent.tabScreens.contains(new) { return .tab }
        return .push
    }

    private var transition: AnyTransition {
        switch navStyle {
        case .tab:
            return .opacity
        case .sheet:
            return .move(edge: .bottom).combined(with: .opacity)
        case .push:
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        }
    }

    var body: some View {
        Group {
            contentFor(s.screen)
        }
        .id(s.screen)
        .transition(transition)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: s.screen)
        .onChange(of: s.screen) { old, new in
            navStyle = styleFor(from: old, to: new)
        }
    }

    @ViewBuilder
    private func contentFor(_ screen: ProtoScreen) -> some View {
        Group {
            switch screen {
            case .month, .weekly: ProtoMonthScreen()
            case .calendarList: ProtoCalendarList()
            case .calendarSettings(let cal): ProtoCalendarSettings(cal: cal)
            case .monthPicker: ProtoMonthPicker()
            case .create: ProtoEventForm()
            case .editEvent(let ev): ProtoEventForm(editing: ev)
            case .noteEdit: ProtoNoteEdit()
            case .eventDetail(let ev): ProtoEventDetail(ev: ev)
            case .liveEventDetail(let ev): ProtoLiveEventDetail(ev: ev)
            case .search: ProtoSearch()
            case .feed: ProtoFeed()
            case .notices: ProtoNotices()
            case .other: ProtoOther()
            case .profile: ProtoProfile()
            case .memos: ProtoMemos()
            case .memosEmpty: ProtoMemosEmpty()
            case .memoDetail(let m): ProtoMemoDetail(memo: m)
            case .liveMemoDetail(let m): ProtoLiveMemoDetail(memo: m)
            case .todos: ProtoTodos()
            case .album: ProtoAlbum()
            case .members: ProtoMembers()
            case .invite: ProtoInvite()
            case .extSubscribe: ProtoExtSubscribe()
            case .availability: ProtoAvailability()
            case .settings: ProtoSettings()
            case .displaySettings: ProtoDisplaySettings()
            case .filterSettings: ProtoFilterSettings()
            case .displayCalendar: ProtoDisplayCalendar()
            case .widgetCalendar: ProtoWidgetCalendar()
            case .notifSettings: ProtoNotifSettings()
            case .noticeBoard: ProtoNoticeBoard()
            case .noticeDetail: ProtoNoticeDetail()
            case .premium: ProtoPremium()
            case .premiumDetail: ProtoPremiumDetail()
            case .helpHome: ProtoHelpHome()
            case .helpCategory(let c): ProtoHelpCategory(cat: c)
            case .helpArticle(let a): ProtoHelpArticle(article: a)
            case .faq: ProtoFAQ()
            case .contact: ProtoContact()
            case .userGuide: ProtoUserGuide()
            default: ProtoMonthScreen()
            }
        }
    }
}

struct PremiumUpsell: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { s.upsell = false }
            VStack(spacing: 12) {
                Image(systemName: "paperclip").font(.system(size: 34)).foregroundStyle(PT.soft)
                Text("使用 MangoTime 高級版上傳文件").font(.headline)
                Text("並隨時確認").font(.subheadline).foregroundStyle(PT.soft)
                Text("您有這樣的煩惱嗎？\n孩子學校的通知書、活動嘅 PDF…").font(.footnote).foregroundStyle(PT.soft).multilineTextAlignment(.center)
                Button { s.upsell = false; s.screen = .premiumDetail } label: {
                    Text("了解 Premium").bold().foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button("唔該，而家唔使") { s.upsell = false }.font(.footnote).foregroundStyle(PT.soft)
            }
            .padding(22)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
    }
}

struct PhotoPermAlert: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("允許「MangoTime」取用您的相片嗎？").font(.headline).multilineTextAlignment(.center)
                Text("app 需要相片權限先可以上傳至相簿").font(.footnote).foregroundStyle(PT.soft).multilineTextAlignment(.center)
                Divider()
                Button("允許取用所有相片") { s.photoPerm = false; s.note("已取得權限（mock）") }
                Divider()
                Button("限制取用…") { s.photoPerm = false }
                Divider()
                Button("唔允許") { s.photoPerm = false }.foregroundStyle(.red)
            }
            .padding(.top, 18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 60)
        }
    }
}
