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
                        EmptyState(icon: "newspaper", title: "無最新動態", sub: "呢個行事曆仲未有更新。")
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
                            EmptyState(icon: "photo.on.rectangle", title: "無最新動態", sub: "呢個行事曆仲未有相簿更新。")
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
                                Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(PT.soft)
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
                        EmptyState(icon: "photo.on.rectangle", title: "無最新動態", sub: "呢個行事曆仲未有相簿更新。")
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
                    EmptyState(icon: "bell", title: "冇通知", sub: "其他成員郁手就會喺度見到。")
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
                noticeRow(icon: "bell", text: "聽日 19:00「屋企人飯局」", sub: "提醒")
                noticeRow(icon: "person.2", text: "阿女接受咗你嘅邀請", sub: "昨日")
            }
        }
    }
    private func noticeRow(icon: String, text: String, sub: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(PT.soft)
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
                        .padding(.horizontal, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 10)
                    Button { s.screen = .premiumDetail } label: {
                        HStack {
                            Label("MangoTime Premium", systemImage: "star.fill").bold().foregroundStyle(PT.orange)
                            Spacer()
                            Text("了解詳情 ›").font(.caption).foregroundStyle(PT.soft).lineLimit(1)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.vertical, 12)
                    PCard {
                        PRow(icon: "calendar", label: "行事曆清單") { s.screen = .calendarList }
                        PRow(icon: "doc.text", label: "備忘錄") { s.screen = .memos }
                        PRow(icon: "checkmark.square", label: "待辦清單") { s.screen = .todos }
                        PRow(icon: "photo.on.rectangle", label: "相簿") { s.screen = .album }
                        PRow(icon: "person.2", label: "成員") { s.screen = .members }
                        PRow(icon: "link", label: "訂閱外部日曆") { s.screen = .extSubscribe }
                        PRow(icon: "square.and.arrow.up", label: "分享有空嘅日子") { s.screen = .availability }
                    }
                    PCard {
                        PRow(icon: "gearshape", label: "App 設定") { s.screen = .settings }
                        PRow(icon: "megaphone", label: "公告") { s.screen = .noticeBoard }
                        PRow(icon: "book", label: "MangoTime 使用手冊") { s.screen = .userGuide }
                        PRow(icon: "questionmark.circle", label: "使用方法") { s.screen = .helpHome }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// 訂閱外部日曆（task 5.1）：貼 .ics 連結
struct ProtoExtSubscribe: View {
    @EnvironmentObject var s: ProtoState
    @State private var url = ""
    @State private var name = ""
    @State private var busy = false
    @State private var externals: [MTExternal] = []

    var body: some View {
        PSheet(title: "訂閱外部日曆", onBack: { s.screen = .other }) {
            // content
            if s.api == nil {
                Text("貼上 Google 日曆／Apple 日曆嘅 .ics 連結，對方嘅活動就會以唯讀方式顯示喺你嘅月曆。")
                    .font(.caption).foregroundStyle(PT.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                PRow(icon: "link", label: "學校校曆", value: "已訂閱") { s.note("取消訂閱（mock）") }
                PRow(icon: "link", label: "波場訂場", value: "已訂閱") { s.note("取消訂閱（mock）") }
            } else {
                Text("貼上 Google 日曆（設定→日曆→整合日曆→秘密地址）或 Apple 日曆（發佈日曆）嘅 .ics 連結。")
                    .font(.caption).foregroundStyle(PT.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                if externals.isEmpty {
                    Text("仲未訂閱任何外部日曆").font(.caption).foregroundStyle(PT.soft).padding(.top, 8)
                }
                ForEach(externals) { e in
                    PRow(icon: "link", label: e.name, value: "已訂閱") { }
                }
                // 5.5 iCal 備份/搬屋
                Divider().padding(.vertical, 10)
                IcsExportRow()
                IcsImportRow()
            }
        } bottom: {
            if s.api != nil {
                HStack {
                    TextField("https://…/basic.ics", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("ext_url")
                    Button {
                        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !u.isEmpty, !busy, let calId = s.activeCalendarId else { return }
                        busy = true
                        Task {
                            defer { busy = false }
                            if (try? await s.api?.subscribeExternal(calendarId: calId, url: u, name: name.isEmpty ? nil : name)) != nil {
                                url = ""
                                s.note("已訂閱 ✓")
                            } else {
                                s.note("訂閱失敗——條 link 攞唔到嘢")
                            }
                        }
                    } label: { Text(busy ? "…" : "訂閱").bold().foregroundStyle(PT.orange) }
                }
            }
        }
    }
}

/// 5.5 匯出 .ics（share sheet 分享個檔）
struct IcsExportRow: View {
    @EnvironmentObject var s: ProtoState
    @State private var shareData: Data?
    var body: some View {
        Button {
            Task {
                guard let calId = s.activeCalendarId else { return }
                if let data = try? await s.api?.exportIcs(calendarId: calId) { shareData = data }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up").foregroundStyle(PT.soft).frame(width: 20)
                Text("匯出行事曆（.ics）").foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .overlay(Divider().opacity(0.6), alignment: .bottom)
        .sheet(isPresented: Binding(get: { shareData != nil }, set: { if !$0 { shareData = nil } })) {
            if let shareData {
                ShareSheet(items: [shareData])
            }
        }
    }
}

/// 5.5 匯入 .ics
struct IcsImportRow: View {
    @EnvironmentObject var s: ProtoState
    @State private var showPicker = false
    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down").foregroundStyle(PT.soft).frame(width: 20)
                Text("匯入 .ics 檔案").foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .overlay(Divider().opacity(0.6), alignment: .bottom)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.init(filenameExtension: "ics")!]) { result in
            guard case .success(let fileUrl) = result else { return }
            Task {
                guard let calId = s.activeCalendarId else { return }
                let ok = fileUrl.startAccessingSecurityScopedResource()
                defer { if ok { fileUrl.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: fileUrl),
                   let text = String(data: data, encoding: .utf8),
                   let n = try? await s.api?.importIcs(calendarId: calId, ics: text) {
                    s.note("已匯入 \(n) 個活動 ✓")
                    await s.loadLive()
                } else {
                    s.note("匯入失敗")
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ProtoProfile: View {
    @EnvironmentObject var s: ProtoState
    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var birthday = Date()
    @State private var birthdayOn = false
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
            .onAppear {
                if let bd = s.api?.currentUser?.birthdate {
                    birthdayOn = true
                    let f = DateFormatter(); f.dateFormat = "MM-dd"
                    // 用今年嘅日期裝返個 Date
                    let y = Calendar.current.component(.year, from: Date())
                    var c = DateComponents(); c.year = y
                    c.month = Int(bd.prefix(2)); c.day = Int(bd.suffix(2))
                    if let d = Calendar.current.date(from: c) { birthday = d }
                }
            }
            if editingName {
                HStack {
                    TextField("名稱", text: $nameDraft).textFieldStyle(.roundedBorder)
                    Button("保存") {
                        editingName = false
                        Task { try? await s.api?.updateMe(displayName: nameDraft); s.note("已更新 ✓") }
                    }.foregroundStyle(PT.orange).bold()
                }
            } else {
                PRow(label: "名稱", value: name) {
                    nameDraft = name
                    editingName = true
                }
            }
            PRow(label: "電郵", value: email)
            // 生日（成員生日自動上曆）
            VStack(alignment: .leading, spacing: 6) {
                PRow(label: "生日", toggle: $birthdayOn)
                if birthdayOn {
                    DatePicker("生日", selection: $birthday, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: birthday) { _, d in
                            let f = DateFormatter(); f.dateFormat = "MM-dd"
                            Task { try? await s.api?.updateMe(birthdate: f.string(from: d)); s.note("生日已保存 ✓") }
                        }
                }
            }
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
                        if let c = m.commentCount, c > 0 { HStack(spacing: 2) { Image(systemName: "bubble"); Text("\(c)") }.font(.caption).foregroundStyle(PT.soft) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                    }
                    .padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
            if liveMemos.isEmpty {
                EmptyState(icon: "doc.text", title: "找不到備忘錄。", sub: "請透過下方建立新的備忘錄。")
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
            EmptyState(icon: "doc.text", title: "找不到備忘錄。", sub: "請透過下方的［+］按鈕建立新的備忘錄。")
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
                Label("標籤", systemImage: "tag")
                Spacer()
                Circle().fill(memo.color).frame(width: 10, height: 10)
                Text("備忘錄").font(.subheadline).foregroundStyle(PT.soft)
            }
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
            PRow(icon: "note.text", label: "內容", value: memo.body)
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
                EmptyState(icon: "checkmark.square", title: "找不到待辦清單。", sub: "請透過下方建立新的清單。")
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
                EmptyState(icon: "photo.on.rectangle", title: "仲未有相。", sub: "撳右上 ＋ 上傳第一張。")
            }
            // 按月分組（TimeTree 相簿 feed 式）
            ForEach(photoMonthGroups, id: \.0) { group in
                Text(group.0).font(.caption).bold().foregroundStyle(PT.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(group.1) { p in
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
                .padding(.top, 4)
            }
        }
        .onAppear { Task { await reload() } }
    }

    // "2026年11月" → [photos]（相簿按月分組）
    private var photoMonthGroups: [(String, [MTPhoto])] {
        var groups: [(String, [MTPhoto])] = []
        var key = ""
        for p in livePhotos {
            var label = "早前"
            if let iso = p.createdAt, let d = parseISODate(iso) {
                let f = DateFormatter(); f.locale = Locale(identifier: "zh_HK"); f.dateFormat = "yyyy年M月"
                label = f.string(from: d)
            }
            if label != key { key = label; groups.append((label, [])) }
            groups[groups.count - 1].1.append(p)
        }
        return groups
    }

    private var mockAlbum: some View {
        PSheet(title: "相簿", onBack: { s.screen = .other }, right: AnyView(
            Button { s.photoPerm = true } label: { Text("＋").foregroundStyle(PT.orange) }
        )) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Mock.photos, id: \.self) { p in
                    Image(systemName: p).font(.system(size: 26)).foregroundStyle(PT.soft)
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


/// 成員顏色字串 → Color（同 label 色共用）
func memberColor(_ key: String?, fallback: Color) -> Color {
    switch key {
    case "bright-orange": return PT.orange
    case "emerald": return PT.green
    case "blue": return PT.blue
    case "red": return PT.red
    case "purple": return PT.purple
    default: return fallback
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
                    // 成員顏色：自己可以撳嚟轉色
                    Button {
                        guard m.userId == s.api?.currentUser?.id else { return }
                        let order: [String] = ["bright-orange", "emerald", "blue", "red", "purple"]
                        let next = order[(order.firstIndex(of: m.color ?? "bright-orange") ?? -1 + 1) % order.count]
                        Task {
                            try? await s.api?.setMemberColor(calendarId: s.activeCalendarId ?? "", userId: m.userId, color: next)
                            await s.loadMembers()
                        }
                    } label: {
                        Circle().fill(memberColor(m.color, fallback: colors[i % colors.count])).frame(width: 36, height: 36)
                            .overlay(Text(String(m.displayName.prefix(1))).foregroundStyle(.white).bold())
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.displayName).bold()
                        HStack(spacing: 6) {
                            Text(m.role == "creator" ? "建立者" : "成員")
                            if let seen = m.lastSeenAt, let d = parseISODate(seen) {
                                Text("· 最後查看 \(relTimeText(d))")
                            }
                        }
                        .font(.caption).foregroundStyle(PT.soft)
                    }
                    Spacer()
                    // creator 可以踢人（唔係自己）
                    if s.liveMembers.first(where: { $0.userId == s.api?.currentUser?.id })?.role == "creator" && m.userId != s.api?.currentUser?.id {
                        Button {
                            Task {
                                try? await s.api?.removeMember(calendarId: s.activeCalendarId ?? "", userId: m.userId)
                                await s.loadMembers()
                                s.note("已移除 \(m.displayName)")
                            }
                        } label: {
                            Image(systemName: "person.badge.minus").foregroundStyle(PT.soft)
                        }
                        .buttonStyle(.plain)
                    }
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

            // 兒童/寵物帳童/寵物帳戶（冇 login 嘅名義成員，生日都會上曆）
            VStack(alignment: .leading, spacing: 8) {
                Text("兒童 / 寵物").font(.caption).foregroundStyle(PT.soft)
                ForEach(children) { c in
                    HStack(spacing: 12) {
                        Circle().fill(PT.green).frame(width: 30, height: 30)
                            .overlay(Text(String(c.name.prefix(1))).font(.caption).foregroundStyle(.white).bold())
                        Text(c.name)
                        Spacer()
                        Button {
                            Task {
                                try? await s.api?.removeChild(calendarId: s.activeCalendarId ?? "", childId: c.id)
                                await reloadChildren()
                            }
                        } label: { Image(systemName: "xmark.circle").font(.subheadline).foregroundStyle(PT.soft) }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                }
                HStack {
                    TextField("名（例如：細路、毛毛）", text: $childName).textFieldStyle(.roundedBorder)
                    Button {
                        let n = childName.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        childName = ""
                        Task {
                            try? await s.api?.addChild(calendarId: s.activeCalendarId ?? "", name: n)
                            await reloadChildren()
                            s.note("已加入 ✓")
                        }
                    } label: { Text("加入").bold().foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 7).background(PT.green).clipShape(RoundedRectangle(cornerRadius: 8)) }
                }
            }
            .padding(.top, 18)
        }
        .onAppear { Task { await s.loadMembers(); await reloadChildren() } }
    }

    @State private var children: [MTChild] = []
    @State private var childName = ""
    private func reloadChildren() async {
        children = (try? await s.api?.listChildren(calendarId: s.activeCalendarId ?? "")) ?? []
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
            Divider().padding(.vertical, 10)
            Label("公開唯讀連結（唔使 app 都睇到月曆）", systemImage: "globe").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Task {
                    guard let calId = s.activeCalendarId else { return }
                    if let slug = try? await s.api?.enablePublic(calendarId: calId) {
                        UIPasteboard.general.string = "https://mangotime.149-28-154-219.sslip.io/public/\(slug)"
                        s.note("公開連結已複製 ✓")
                    }
                }
            } label: {
                Text("開＋複製公開連結").bold().foregroundStyle(PT.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(PT.orange.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
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


/// 相對時間（x 分鐘前）
func relTimeText(_ d: Date) -> String {
    let diff = Date().timeIntervalSince(d)
    if diff < 60 { return "啱啱" }
    if diff < 3600 { return "\(Int(diff/60)) 分鐘前" }
    if diff < 86400 { return "\(Int(diff/3600)) 小時前" }
    return "\(Int(diff/86400)) 日前"
}
