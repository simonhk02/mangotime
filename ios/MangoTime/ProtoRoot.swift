import SwiftUI

/// 原型全域狀態 + 根視圖（splash → login → tab app）
enum ProtoScreen: Hashable {
    case splash, login
    case month, weekly
    case calendarList, monthPicker
    case create, noteEdit
    case eventDetail(MockEvent)
    case search
    case feed, notices, other, profile
    case memos, memosEmpty, memoDetail(MockMemo)
    case todos, album, members, invite
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

    var body: some View {
        ZStack(alignment: .top) {
            switch s.screen {
            case .splash: SplashView()
            case .login: ProtoLoginView()
            default:
                VStack(spacing: 0) {
                    ProtoContent()
                    if [.month, .weekly, .feed, .notices, .other].contains(s.screen) {
                        ProtoTabBar()
                    }
                }
            }
            if !s.toast.isEmpty {
                Text(s.toast)
                    .font(.footnote).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color(.label).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 50)
                    .transition(.opacity)
            }
            if s.upsell { PremiumUpsell() }
            if s.photoPerm { PhotoPermAlert() }
        }
        .environmentObject(s)
    }
}

struct SplashView: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        Button { s.screen = .login } label: {
            VStack(spacing: 12) {
                Spacer()
                Text("🥭").font(.system(size: 84))
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
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("MangoTime").font(.largeTitle).bold()
            Text("一齊夾時間，一家人一個曆").font(.subheadline).foregroundStyle(PT.soft)
            TextField("電郵", text: .constant("")).textFieldStyle(.roundedBorder).keyboardType(.emailAddress)
            SecureField("密碼", text: .constant("")).textFieldStyle(.roundedBorder)
            Button { s.screen = .month } label: {
                Text("登入").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
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
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct ProtoTabBar: View {
    @EnvironmentObject var s: ProtoState
    func tab(_ icon: String, _ label: String, _ target: ProtoScreen, _ active: Bool) -> some View {
        Button { s.screen = target } label: {
            VStack(spacing: 2) {
                Text(icon).font(.system(size: 20))
                Text(label).font(.system(size: 10))
            }
            .foregroundStyle(active ? PT.orange : PT.soft)
            .frame(maxWidth: .infinity)
        }
    }
    var body: some View {
        HStack(alignment: .bottom) {
            tab("📅", "行事曆", .month, s.screen == .month || s.screen == .weekly)
            tab("📰", "最新動態", .feed, s.screen == .feed)
            Button { s.screen = .create } label: {
                Text("＋").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 50, height: 50).background(PT.orange).clipShape(Circle())
                    .shadow(color: PT.orange.opacity(0.4), radius: 6, y: 3)
            }
            .frame(maxWidth: .infinity)
            tab("🔔", "通知", .notices, s.screen == .notices)
            tab("☰", "其他", .other, s.screen == .other)
        }
        .padding(.top, 6).padding(.bottom, 4)
        .background(Color(.systemBackground).shadow(radius: 2))
    }
}

struct ProtoContent: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        Group {
            switch s.screen {
            case .month, .weekly: ProtoMonthScreen()
            case .calendarList: ProtoCalendarList()
            case .monthPicker: ProtoMonthPicker()
            case .create: ProtoEventForm()
            case .noteEdit: ProtoNoteEdit()
            case .eventDetail(let ev): ProtoEventDetail(ev: ev)
            case .search: ProtoSearch()
            case .feed: ProtoFeed()
            case .notices: ProtoNotices()
            case .other: ProtoOther()
            case .profile: ProtoProfile()
            case .memos: ProtoMemos()
            case .memosEmpty: ProtoMemosEmpty()
            case .memoDetail(let m): ProtoMemoDetail(memo: m)
            case .todos: ProtoTodos()
            case .album: ProtoAlbum()
            case .members: ProtoMembers()
            case .invite: ProtoInvite()
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
                Text("📎").font(.system(size: 40))
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
