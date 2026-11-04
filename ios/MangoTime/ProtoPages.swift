import SwiftUI

struct ProtoFeed: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
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
    var body: some View {
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
    var body: some View {
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
    var body: some View {
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
    var body: some View {
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
    var body: some View {
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
