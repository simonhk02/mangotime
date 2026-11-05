import SwiftUI
import AuthenticationServices

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
    case create, noteEdit
    case editEvent(MTEvent)
    case eventDetail(MockEvent)
    case liveEventDetail(MTEvent)
    case search
    case feed, notices, other, profile
    case memos, memosEmpty, memoDetail(MockMemo), liveMemoDetail(MTMemo)
    case todos, album, members, invite
    case extSubscribe
    case settings, displaySettings, filterSettings, displayCalendar, notifSettings
    case noticeBoard, noticeDetail
    case premium, premiumDetail
    case helpHome, helpCategory(HelpCat), helpArticle(String), faq, contact, userGuide
}

final class ProtoState: ObservableObject {
    @Published var screen: ProtoScreen = .splash
    @Published var lunarOn = true
    @Published var weekStartMonday = true
    @Published var settingsTab = 0 // 0=設定 1=支援
    @Published var feedTab = 0 // 0=行程 1=相簿
    @Published var toast = ""
    @Published var upsell = false
    @Published var photoPerm = false

    // LIVE 模式（api != nil）：月曆/行事曆/活動用真 server data，其餘畫面暫時 mock
    var api: APIClient?
    @Published var liveCalendars: [MTCalendar] = []
    @Published var liveEvents: [MTEvent] = []
    @Published var activeCalendarId: String?
    @Published var loginError: String?
    @Published var liveMembers: [MTMember] = []
    @Published var inviteCode: String?
    @Published var liveExternalEvents: [MTExternalEvent] = []
    @Published var displayMonth = Date() // 月曆而家顯示緊邊個月（‹ › 導航）

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
            if activeCalendarId == nil { activeCalendarId = liveCalendars.first?.id }
            if let calId = activeCalendarId {
                let cal = Calendar(identifier: .gregorian)
                let comps = cal.dateComponents([.year, .month], from: month ?? displayMonth)
                let from = cal.date(from: comps)!
                let to = cal.date(byAdding: .month, value: 1, to: from)!
                liveEvents = try await api.listEvents(calendarId: calId, from: from, to: to)
                liveExternalEvents = (try? await api.listExternalEvents(calendarId: calId)) ?? []
            }
        } catch {
            note("載入失敗：\(error.localizedDescription)")
        }
    }

    @MainActor
    func createLiveEvent(title: String, date: Date, allDay: Bool, labelColor: String, location: String?, noteText: String?, repeatRule: String) async {
        guard let api, let calId = activeCalendarId else { return }
        do {
            _ = try await api.createEvent(calendarId: calId, title: title, startsAt: date, allDay: allDay, repeatRule: repeatRule, labelColor: labelColor, location: location, note: noteText)
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
        .background(Color(.systemBackground).shadow(radius: 2))
    }
}

struct ProtoContent: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        Group {
            contentFor(s.screen)
        }
        .id(s.screen)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        .animation(.easeInOut(duration: 0.22), value: s.screen)
    }

    @ViewBuilder
    private func contentFor(_ screen: ProtoScreen) -> some View {
        Group {
            switch screen {
            case .month, .weekly: ProtoMonthScreen()
            case .calendarList: ProtoCalendarList()
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
            case .settings: ProtoSettings()
            case .displaySettings: ProtoDisplaySettings()
            case .filterSettings: ProtoFilterSettings()
            case .displayCalendar: ProtoDisplayCalendar()
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
