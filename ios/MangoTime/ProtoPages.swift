import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ProtoFeed: View {
    @EnvironmentObject var s: ProtoState
    @State private var liveItems: [MTActivity] = []
    @State private var livePhotos: [MTPhoto] = []

    var body: some View {
        if s.api != nil { liveFeed } else { mockFeed }
    }

    private func reload() async {
        guard let calId = s.activeCalendarId else { return }
        if s.feedTab == 0 {
            liveItems = (try? await s.api?.listActivity(calendarId: calId)) ?? []
        } else {
            livePhotos = (try? await s.api?.listPhotos(calendarId: calId)) ?? []
        }
    }

    private func relTime(_ iso: String) -> String {
        guard let d = parseISODate(iso) else { return "" }
        let diff = Date().timeIntervalSince(d)
        if diff < 60 { return "啱啱" }
        if diff < 3600 { return "\(Int(diff/60)) 分鐘前" }
        if diff < 86400 { return "\(Int(diff/3600)) 小時前" }
        return "\(Int(diff/86400)) 日前"
    }

    private var liveFeed: some View {
        VStack(spacing: 0) {
            PNavBar("最新動態", left: {
                Button { s.screen = .calendarList } label: {
                    Text("\(s.liveCalendars.first(where: { $0.id == s.activeCalendarId })?.name ?? "行事曆") ▾").font(.subheadline).foregroundStyle(PT.orange)
                }
            })
            Picker("", selection: $s.feedTab) {
                Text("行程").tag(0); Text("相簿").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .onChange(of: s.feedTab) { _, _ in Task { await reload() } }
            ScrollView {
                if s.feedTab == 0 {
                    if liveItems.isEmpty {
                        EmptyState(icon: "📰", title: "無最新動態", sub: "呢個行事曆仲未有更新。")
                    }
                    ForEach(liveItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: feedIcon(item.type))
                                .font(.subheadline)
                                .foregroundStyle(PT.orange)
                                .frame(width: 28, height: 28)
                                .background(PT.orange.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.actorName) \(item.text)").font(.subheadline)
                                Text(relTime(item.createdAt)).font(.caption).foregroundStyle(PT.soft)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .overlay(Divider().opacity(0.5), alignment: .bottom)
                    }
                } else {
                    if livePhotos.isEmpty {
                        VStack(spacing: 10) {
                            EmptyState(icon: "🖼", title: "無最新動態", sub: "呢個行事曆仲未有相簿更新。")
                            Button { s.screen = .album } label: {
                                Text("去相簿 ›").foregroundStyle(PT.orange)
                            }
                        }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            ForEach(livePhotos) { p in
                                AsyncImage(url: s.api?.fileURL(p.url)) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    default: Color(.secondarySystemBackground)
                                    }
                                }
                                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                .clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 10).padding(.top, 8)
                    }
                }
            }
            .refreshable { await reload() }
        }
        .onAppear { Task { await reload() } }
    }

    /// activity type → SF Symbol（唔用 emoji）
    private func feedIcon(_ type: String) -> String {
        switch type {
        case "calendar.created", "calendar.renamed": return "calendar"
        case "calendar.member_joined": return "person.badge.plus"
        case "calendar.member_removed": return "person.badge.minus"
        case "calendar.invite_created": return "link"
        case "event.created", "event.updated": return "calendar.badge.plus"
        case "event.deleted": return "trash"
        case "event.comment_created", "memo.comment_created": return "text.bubble"
        case "memo.created", "memo.updated": return "note.text"
        case "memo.deleted", "todo.list_deleted": return "trash"
        case "todo.list_created", "todo.item_created": return "checklist"
        case "todo.item_done": return "checkmark.circle.fill"
        case "todo.item_undone": return "circle"
        case "photo.uploaded": return "photo"
        default: return "circle"
        }
    }

    private var mockFeed: some View {
        VStack(spacing: 0) {
            PNavBar("最新動態", left: {
                Button { s.screen = .calendarList } label: {
                    Text("家庭日曆 ▾").font(.subheadline).foregroundStyle(PT.orange)
                }
            })
            Picker("", selection: $s.feedTab) {
                Text("行程").tag(0); Text("相簿").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14).padding(.vertical, 6)
            ScrollView {
                if s.feedTab == 0 {
                    VStack(spacing: 0) {
                        Button { s.screen = .eventDetail(Mock.events[0]) } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("🍖").font(.system(size: 60))
                                    .frame(maxWidth: .infinity).frame(height: 110)
                                    .background(Color(.secondarySystemBackground))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("（A房）BBQ 15人 17:00-23:00").bold()
                                    Text("10月25日 週日 下午7:00").font(.caption).foregroundStyle(PT.soft)
                                    HStack(spacing: 6) {
                                        Circle().fill(PT.orange).frame(width: 18, height: 18)
                                            .overlay(Text("文").font(.system(size: 9)).foregroundStyle(.white))
                                        Text("阿文 新增咗呢個行程").font(.caption).foregroundStyle(PT.soft)
                                    }
                                }
                                .padding(12)
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14).padding(.top, 10)
                        feedRow(avatar: "婆", color: PT.green, text: "老婆 改咗「屋企人飯局」時間", sub: "2 小時前")
                        feedRow(avatar: "女", color: PT.blue, text: "阿女 喺相簿上傳咗 3 張相", sub: "昨日")
                    }
                } else {
                    VStack(spacing: 10) {
                        EmptyState(icon: "🖼", title: "無最新動態", sub: "呢個行事曆仲未有相簿更新。")
                        Button { s.screen = .album } label: {
                            Text("去相簿 ›").foregroundStyle(PT.orange)
                        }
                    }
                }
            }
        }
    }
    private func feedRow(avatar: String, color: Color, text: String, sub: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 32, height: 32)
                .overlay(Text(avatar).font(.caption).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.subheadline)
                Text(sub).font(.caption).foregroundStyle(PT.soft)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(Divider().opacity(0.5).padding(.leading, 56), alignment: .bottom)
    }
}

struct ProtoNotices: View {
    @EnvironmentObject var s: ProtoState
    @State private var liveNotices: [MTNotice] = []
    var body: some View {
        if s.api != nil { liveNoticesView } else { mockNotices }
    }

    private var liveNoticesView: some View {
        VStack(spacing: 0) {
            PNavBar("通知")
            ScrollView {
                if liveNotices.isEmpty {
                    EmptyState(icon: "🔔", title: "冇通知", sub: "其他成員郁手就會喺度見到。")
                }
                ForEach(liveNotices) { n in
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill").foregroundStyle(PT.orange)
                            .frame(width: 28, height: 28)
                            .background(PT.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(n.actorName) \(n.text)").font(.subheadline)
                            Text(n.createdAt.prefix(10)).font(.caption).foregroundStyle(PT.soft)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
            }
            .refreshable { await reload() }
        }
        .onAppear { Task { await reload() } }
    }

    private func reload() async {
        liveNotices = (try? await s.api?.listNotices()) ?? []
    }

    private var mockNotices: some View {
        VStack(spacing: 0) {
            PNavBar("通知")
            ScrollView {
                noticeRow(icon: "🔔", text: "聽日 19:00「屋企人飯局」", sub: "提醒")
                noticeRow(icon: "👥", text: "阿女接受咗你嘅邀請", sub: "昨日")
            }
        }
    }
    private func noticeRow(icon: String, text: String, sub: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.subheadline)
                Text(sub).font(.caption).foregroundStyle(PT.soft)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .overlay(Divider().opacity(0.5), alignment: .bottom)
    }
}

struct ProtoOther: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        VStack(spacing: 0) {
            PNavBar("其他")
            ScrollView {
                VStack(spacing: 0) {
                    Button { s.screen = .profile } label: {
                        HStack(spacing: 12) {
                            Circle().fill(PT.orange).frame(width: 52, height: 52)
                                .overlay(Text(String((s.api?.currentUser?.displayName ?? "阿文").prefix(1))).font(.title3).foregroundStyle(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.api?.currentUser?.displayName ?? "阿文").bold()
                                Text(s.api?.currentUser?.email ?? "simonhk02@gmail.com").font(.caption).foregroundStyle(PT.soft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    Button { s.screen = .premiumDetail } label: {
                        HStack {
                            Text("⭐ MangoTime Premium").bold()
                            Spacer()
                            Text("開始月付HK$23.00的無廣告方案！免費使用1月 ›").font(.caption).foregroundStyle(PT.soft).lineLimit(1)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    PRow(label: "📅 行事曆清單") { s.screen = .calendarList }
                    PRow(label: "📝 備忘錄") { s.screen = .memos }
                    PRow(label: "✅ 待辦清單") { s.screen = .todos }
                    PRow(label: "🖼 相簿") { s.screen = .album }
                    PRow(label: "👥 成員") { s.screen = .members }
                    PRow(label: "⚙️ App 設定") { s.screen = .settings }
                    PRow(label: "📢 公告") { s.screen = .noticeBoard }
                    PRow(label: "📖 樹民的使用手冊") { s.screen = .userGuide }
                    PRow(label: "❓ 使用方法") { s.screen = .helpHome }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct ProtoProfile: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        let user = s.api?.currentUser
        let name = user?.displayName ?? "阿文"
        let email = user?.email ?? "simonhk02@gmail.com"
        PSheet(title: "個人檔案", onBack: { s.screen = .other }) {
            VStack(spacing: 8) {
                Circle().fill(PT.orange).frame(width: 72, height: 72)
                    .overlay(Text(String(name.prefix(1))).font(.title).foregroundStyle(.white))
                Text(name).bold()
                Text(email).font(.caption).foregroundStyle(PT.soft)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            PRow(label: "名稱", value: name) { s.note("改名（mock）") }
            PRow(label: "電郵", value: email)
            PRow(label: "連結帳戶", value: "Google · Apple") { s.note("連結帳戶（mock）") }
            Button {
                if s.api != nil {
                    Task {
                        await s.api?.logout()
                        s.liveCalendars = []; s.liveEvents = []; s.activeCalendarId = nil
                        s.screen = .login
                    }
                } else {
                    s.screen = .login
                }
            } label: {
                Text("登出").bold().foregroundStyle(.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red))
            }
            .padding(.top, 20)
        }
    }
}

struct ProtoMemos: View {
    @EnvironmentObject var s: ProtoState
    @State private var liveMemos: [MTMemo] = []
    @State private var newTitle = ""
    var body: some View {
        if s.api != nil { liveList } else { mockList }
    }

    private func reload() async {
        guard let calId = s.activeCalendarId else { return }
        liveMemos = (try? await s.api?.listMemos(calendarId: calId)) ?? []
    }

    private var liveList: some View {
        PSheet(title: "備忘錄", onBack: { s.screen = .other }, onRefresh: { await reload() }, content: {
            ForEach(liveMemos) { m in
                Button { s.screen = .liveMemoDetail(m) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(m.labelColor == "emerald" ? PT.green : m.labelColor == "blue" ? PT.blue : PT.orange).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).bold().foregroundStyle(.primary)
                            if !m.body.isEmpty { Text(m.body).font(.caption).foregroundStyle(PT.soft).lineLimit(1) }
                        }
                        Spacer()
                        if let c = m.commentCount, c > 0 { Text("💬\(c)").font(.caption).foregroundStyle(PT.soft) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                    }
                    .padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
            if liveMemos.isEmpty {
                EmptyState(icon: "📝", title: "找不到備忘錄。", sub: "請透過下方建立新的備忘錄。")
            }
        }, bottom: {
            HStack {
                TextField("新備忘錄標題", text: $newTitle).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("memo_new_title")
                Button {
                    let t = newTitle.trimmingCharacters(in: .whitespaces)
                    guard let calId = s.activeCalendarId, !t.isEmpty else { return }
                    hideKeyboard()
                    newTitle = ""
                    Task {
                        _ = try? await s.api?.createMemo(calendarId: calId, title: t, body: "")
                        await reload()
                        s.note("已建立 ✓")
                    }
                } label: {
                    Text("建立").bold().foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        })
        .onAppear { Task { await reload() } }
    }

    private var mockList: some View {
        PSheet(title: "備忘錄", onBack: { s.screen = .other }, right: AnyView(
            Button { s.note("新增備忘錄（mock）") } label: { Text("＋").foregroundStyle(PT.orange) }
        )) {
            ForEach(Mock.memos) { m in
                Button { s.screen = .memoDetail(m) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(m.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).bold().foregroundStyle(.primary)
                            Text(m.body).font(.caption).foregroundStyle(PT.soft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                    }
                    .padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
            Button { s.screen = .memosEmpty } label: {
                Text("（空態預覽 ›）").font(.caption).foregroundStyle(PT.soft)
            }
            .padding(.top, 14)
        }
    }
}

struct ProtoMemosEmpty: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "備忘錄", onBack: { s.screen = .memos }) {
            EmptyState(icon: "📝", title: "找不到備忘錄。", sub: "請透過下方的［+］按鈕建立新的備忘錄。")
            Button { s.note("新增備忘錄（mock）") } label: {
                Text("新增備忘錄").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 20)
        }
    }
}

struct ProtoLiveMemoDetail: View {
    @EnvironmentObject var s: ProtoState
    let memo: MTMemo
    @State private var comments: [MTComment] = []
    @State private var draft = ""

    var body: some View {
        PSheet(title: memo.title, onBack: { s.screen = .memos }, right: AnyView(
            Button {
                Task {
                    try? await s.api?.deleteMemo(id: memo.id)
                    s.note("已刪除 ✓"); s.screen = .memos
                }
            } label: { Text("刪除").foregroundStyle(.red) }
        )) {
            if !memo.body.isEmpty {
                Text(memo.body).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    .overlay(Divider().opacity(0.6), alignment: .bottom)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("留言").font(.caption).foregroundStyle(PT.soft)
                ForEach(comments) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.body).font(.subheadline)
                        Text(c.authorName).font(.caption2).foregroundStyle(PT.soft)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack {
                    TextField("留言…", text: $draft).textFieldStyle(.roundedBorder)
                    Button {
                        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        hideKeyboard()
                        Task {
                            if let c = try? await s.api?.postMemoComment(memoId: memo.id, body: t) {
                                comments.append(c); draft = ""
                            }
                        }
                    } label: { Text("送出").foregroundStyle(PT.orange).bold() }
                }
            }
            .padding(.top, 14)
        }
        .onAppear { Task { comments = (try? await s.api?.listMemoComments(memoId: memo.id)) ?? [] } }
    }
}

struct ProtoMemoDetail: View {
    @EnvironmentObject var s: ProtoState
    let memo: MockMemo
    var body: some View {
        PSheet(title: memo.title, onBack: { s.screen = .memos }, right: AnyView(
            Button { s.note("編輯（mock）") } label: { Text("編輯").foregroundStyle(PT.orange) }
        )) {
            HStack {
                Text("🏷 標籤")
                Spacer()
                Circle().fill(memo.color).frame(width: 10, height: 10)
                Text("備忘錄").font(.subheadline).foregroundStyle(PT.soft)
            }
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
            PRow(label: "🗒 內容", value: memo.body)
            ChatBox(msgs: [("阿女", "貓糧要無穀物嗰隻吖", false)])
        }
    }
}

struct ProtoTodos: View {
    @EnvironmentObject var s: ProtoState
    @State private var todos = Mock.todos
    @State private var liveLists: [MTTodoList] = []
    @State private var newListTitle = ""
    @State private var newItemText: [String: String] = [:]

    var body: some View {
        if s.api != nil { liveTodos } else { mockTodos }
    }

    private func reload() async {
        guard let calId = s.activeCalendarId else { return }
        liveLists = (try? await s.api?.listTodos(calendarId: calId)) ?? []
    }

    private var liveTodos: some View {
        PSheet(title: "待辦清單", onBack: { s.screen = .other }, onRefresh: { await reload() }, content: {
            ForEach(liveLists) { list in
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(list.title).bold()
                        Spacer()
                        Text("\(list.done)/\(list.total) 已完成").font(.caption).foregroundStyle(PT.soft)
                        Button {
                            Task { try? await s.api?.deleteTodoList(id: list.id); await reload() }
                        } label: { Image(systemName: "trash").font(.caption).foregroundStyle(.red) }
                    }
                    .padding(.vertical, 10)
                    ForEach(list.items) { item in
                        Button {
                            Task {
                                try? await s.api?.toggleTodoItem(itemId: item.id, done: !item.done)
                                await reload()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6).stroke(item.done ? PT.green : Color(.separator), lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                    if item.done {
                                        RoundedRectangle(cornerRadius: 6).fill(PT.green).frame(width: 22, height: 22)
                                        Text("✓").font(.caption).bold().foregroundStyle(.white)
                                    }
                                }
                                Text(item.text)
                                    .strikethrough(item.done)
                                    .foregroundStyle(item.done ? PT.soft : .primary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        TextField("加一項…", text: Binding(
                            get: { newItemText[list.id] ?? "" },
                            set: { newItemText[list.id] = $0 }
                        )).textFieldStyle(.roundedBorder)
                        Button {
                            let t = (newItemText[list.id] ?? "").trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return }
                            hideKeyboard()
                            newItemText[list.id] = ""
                            Task {
                                try? await s.api?.addTodoItem(listId: list.id, text: t)
                                await reload()
                            }
                        } label: { Text("加").bold().foregroundStyle(PT.orange) }
                    }
                    .padding(.bottom, 10)
                    Divider()
                }
            }
            if liveLists.isEmpty {
                EmptyState(icon: "✅", title: "找不到待辦清單。", sub: "請透過下方建立新的清單。")
            }
        }, bottom: {
            HStack {
                TextField("新清單名稱", text: $newListTitle).textFieldStyle(.roundedBorder)
                Button {
                    let t = newListTitle.trimmingCharacters(in: .whitespaces)
                    guard let calId = s.activeCalendarId, !t.isEmpty else { return }
                    hideKeyboard()
                    newListTitle = ""
                    Task {
                        try? await s.api?.createTodoList(calendarId: calId, title: t)
                        await reload()
                        s.note("已建立 ✓")
                    }
                } label: {
                    Text("＋ 新增清單").bold().foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        })
        .onAppear { Task { await reload() } }
    }

    private var mockTodos: some View {
        PSheet(title: "待辦清單", onBack: { s.screen = .other }, right: AnyView(
            Button { s.note("新增清單（mock）") } label: { Text("＋").foregroundStyle(PT.orange) }
        )) {
            Text("\(todos.filter(\.done).count)/\(todos.count) 已完成")
                .font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            ForEach(todos) { t in
                Button {
                    if let i = todos.firstIndex(where: { $0.id == t.id }) { todos[i].done.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).stroke(t.done ? PT.green : Color(.separator), lineWidth: 2)
                                .frame(width: 22, height: 22)
                            if t.done {
                                RoundedRectangle(cornerRadius: 6).fill(PT.green).frame(width: 22, height: 22)
                                Text("✓").font(.caption).bold().foregroundStyle(.white)
                            }
                        }
                        Text(t.text)
                            .strikethrough(t.done)
                            .foregroundStyle(t.done ? PT.soft : .primary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProtoAlbum: View {
    @EnvironmentObject var s: ProtoState
    @State private var livePhotos: [MTPhoto] = []
    @State private var pickedItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var busyId: String?

    var body: some View {
        if s.api != nil { liveAlbum } else { mockAlbum }
    }

    private func reload() async {
        guard let calId = s.activeCalendarId else { return }
        livePhotos = (try? await s.api?.listPhotos(calendarId: calId)) ?? []
    }

    private var liveAlbum: some View {
        PSheet(title: "相簿", onBack: { s.screen = .other }, right: AnyView(
            PhotosPicker(selection: $pickedItem, matching: .images) {
                if uploading { ProgressView() } else { Text("＋").foregroundStyle(PT.orange) }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                uploading = true
                Task {
                    defer { uploading = false; pickedItem = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let calId = s.activeCalendarId else { return }
                    // HEIC/JPEG 都得；壓縮過 8MB 先上
                    var mime = "image/jpeg"
                    var payload = data
                    if let uiimg = UIImage(data: data), let jpg = uiimg.jpegData(compressionQuality: 0.8) {
                        payload = jpg
                    } else if data.count > 7_000_000 {
                        s.note("相太大，揀張細啲嘅"); return
                    }
                    if let uti = item.supportedContentTypes.first, uti.conforms(to: .png) { mime = "image/png" }
                    _ = try? await s.api?.uploadPhoto(calendarId: calId, data: payload, mimeType: mime)
                    await reload()
                    s.note("已上傳 ✓")
                }
            }
        ), onRefresh: { await reload() }) {
            if livePhotos.isEmpty {
                EmptyState(icon: "🖼", title: "仲未有相。", sub: "撳右上 ＋ 上傳第一張。")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(livePhotos) { p in
                    AsyncImage(url: s.api?.fileURL(p.url)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Color(.secondarySystemBackground)
                        }
                    }
                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onLongPressGesture {
                        guard p.uploaderId == s.api?.currentUser?.id else { return }
                        busyId = p.id
                        Task {
                            try? await s.api?.deletePhoto(id: p.id)
                            await reload()
                            s.note("已刪除 ✓")
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .onAppear { Task { await reload() } }
    }

    private var mockAlbum: some View {
        PSheet(title: "相簿", onBack: { s.screen = .other }, right: AnyView(
            Button { s.photoPerm = true } label: { Text("＋").foregroundStyle(PT.orange) }
        )) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Mock.photos, id: \.self) { p in
                    Text(p).font(.system(size: 40))
                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { s.note("相片詳情（mock）") }
                }
            }
            .padding(.top, 10)
        }
    }
}

struct ProtoMembers: View {
    @EnvironmentObject var s: ProtoState
    private let colors: [Color] = [PT.orange, PT.green, PT.blue, PT.purple, PT.red]
    var body: some View {
        if s.api != nil { liveMembers } else { mockMembers }
    }

    private var liveMembers: some View {
        PSheet(title: "成員（\(s.liveMembers.count)）", onBack: { s.screen = .other }, onRefresh: { await s.loadMembers() }) {
            ForEach(Array(s.liveMembers.enumerated()), id: \.element.id) { i, m in
                HStack(spacing: 12) {
                    Circle().fill(colors[i % colors.count]).frame(width: 36, height: 36)
                        .overlay(Text(String(m.displayName.prefix(1))).foregroundStyle(.white).bold())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.displayName).bold()
                        Text(m.role == "creator" ? "建立者" : "成員").font(.caption).foregroundStyle(PT.soft)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .overlay(Divider().opacity(0.5), alignment: .bottom)
            }
            Button { s.screen = .invite } label: {
                Text("＋ 邀請成員").bold().foregroundStyle(PT.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 14)
        }
        .onAppear { Task { await s.loadMembers() } }
    }

    private var mockMembers: some View {
        PSheet(title: "成員（3）", onBack: { s.screen = .other }) {
            ForEach(Mock.members) { m in
                HStack(spacing: 12) {
                    Circle().fill(m.color).frame(width: 36, height: 36)
                        .overlay(Text(String(m.name.prefix(1))).foregroundStyle(.white).bold())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name).bold()
                        Text(m.role).font(.caption).foregroundStyle(PT.soft)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .overlay(Divider().opacity(0.5), alignment: .bottom)
            }
            Button { s.screen = .invite } label: {
                Text("＋ 邀請成員").bold().foregroundStyle(PT.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 14)
        }
    }
}

struct ProtoInvite: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        if s.api != nil { liveInvite } else { mockInvite }
    }

    private var liveInvite: some View {
        PSheet(title: "邀請成員", onBack: { s.screen = .members }) {
            Text("任何人有呢個碼就入到你嘅行事曆：")
                .font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            HStack {
                Text(s.inviteCode ?? "載入中…").font(.title3).bold().lineLimit(1)
                Spacer()
                Button {
                    if let c = s.inviteCode {
                        UIPasteboard.general.string = "mangotime.app/join/\(c)"
                        s.note("已複製 ✓")
                    }
                } label: {
                    Text("複製").bold().foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("對方喺佢 app 嘅「行事曆清單」撳「用邀請碼加入」，輸入呢個碼就入到。")
                .font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
        .onAppear { Task { await s.loadInvite() } }
    }

    private var mockInvite: some View {
        PSheet(title: "邀請成員", onBack: { s.screen = .members }) {
            Text("任何人撳呢條連結就入到「家庭日曆」：")
                .font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            HStack {
                Text("mangotime.app/join/FAM-8X3K").font(.footnote).lineLimit(1)
                Spacer()
                Button { s.note("已複製連結（mock）") } label: {
                    Text("複製").bold().foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("▦▦▦\n▦ QR ▦\n▦▦▦")
                .font(.title3).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            Text("或者俾佢掃 QR code").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity)
            Button { s.note("WhatsApp 分享（mock）") } label: {
                Text("經 WhatsApp 送出").bold().foregroundStyle(PT.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 16)
        }
    }
}
