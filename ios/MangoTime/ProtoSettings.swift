import SwiftUI

struct ProtoSettings: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "App設定", onBack: { s.screen = .other }, backText: "×") {
            Picker("", selection: $s.settingsTab) {
                Text("設定").tag(0); Text("支援").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 10)
            if s.settingsTab == 0 {
                settingsPane
            } else {
                supportPane
            }
        }
    }

    private var settingsPane: some View {
        Group {
            Text("基本設定").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
            PRow(label: "語言", value: "中文") { s.note("語言（mock）") }
            PRow(label: "節日", value: "香港") { s.note("節日（mock）") }
            PRow(icon: "display", label: "顯示設定") { s.screen = .displaySettings }
            PRow(icon: "line.3.horizontal.decrease", label: "篩選設定") { s.screen = .filterSettings }
            Text("通知").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
            PRow(icon: "bell", label: "通知設定") { s.screen = .notifSettings }
            Text("今日行程").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
            PRow(label: "無行程的日子也通知", toggle: .constant(false))
            PRow(label: "只通知有參加的行事", toggle: .constant(true))
            PRow(label: "通知時間", value: "09:00") { s.note("通知時間（mock）") }
        }
    }

    private var supportPane: some View {
        Group {
            Text("幫助").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
            PRow(icon: "megaphone", label: "公告") { s.screen = .noticeBoard }
            PRow(icon: "book", label: "MangoTime 使用手冊") { s.screen = .userGuide }
            PRow(icon: "questionmark.circle", label: "使用方法") { s.screen = .helpHome }
            PRow(icon: "person.raised.hand", label: "常見問題") { s.screen = .faq }
            PRow(icon: "envelope", label: "詢問") { s.screen = .contact }
            Text("社群").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
            PRow(icon: "globe", label: "官方網站") { s.note("網站（mock）") }
            PRow(icon: "at", label: "X / Twitter") { s.note("X（mock）") }
            PRow(icon: "star", label: "喺 App Store 評分") { s.note("評分（mock）") }
        }
    }
}

struct ProtoDisplaySettings: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "顯示設定", onBack: { s.screen = .settings }) {
            PRow(label: "一週嘅開始", value: s.weekStartMonday ? "週一" : "週日") { s.weekStartMonday.toggle() }
            PRow(label: "農曆顯示", toggle: $s.lunarOn)
            PRow(label: "第幾週", toggle: $s.weekNumbersOn)
            PRow(label: "公眾假期", toggle: $s.holidaysOn)
            PRow(label: "24 小時制", toggle: $s.hour24)
            HStack {
                Text("字體大小")
                Spacer()
                Picker("", selection: $s.fontSizeIdx) {
                    Text("小").tag(0); Text("中").tag(1); Text("大").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
            PRow(label: "行事曆顯示") { s.screen = .displayCalendar }
            if s.api != nil {
                PRow(icon: "square.grid.2x2", label: "小工具顯示嘅行事曆", value: s.liveCalendars.first(where: { $0.id == s.widgetCalendarId })?.name ?? "跟而家揀緊嗰個") { s.screen = .widgetCalendar }
            }
        }
    }
}

struct ProtoDisplayCalendar: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "行事曆顯示", onBack: { s.screen = .displaySettings }) {
            if s.api != nil {
                ForEach(s.liveCalendars) { cal in
                    PRow(label: cal.name, toggle: Binding(
                        get: { !s.hiddenCalendarIds.contains(cal.id) },
                        set: { on in
                            if on { s.hiddenCalendarIds.remove(cal.id) } else { s.hiddenCalendarIds.insert(cal.id) }
                        }
                    ))
                }
                Text("隱藏嘅行事曆唔會喺月曆顯示。").font(.caption).foregroundStyle(PT.soft).padding(.top, 8)
            } else {
                PRow(label: "家庭日曆", toggle: .constant(true))
                PRow(label: "工作", toggle: .constant(true))
            }
        }
    }
}

/// 小工具顯示邊個曆（TimeTree「在其他功能中顯示的行事曆」）
struct ProtoWidgetCalendar: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "小工具顯示", onBack: { s.screen = .displaySettings }) {
            PRow(label: "跟而家揀緊嗰個", value: s.widgetCalendarId == nil ? "✓" : "") { s.widgetCalendarId = nil }
            ForEach(s.liveCalendars) { cal in
                PRow(label: cal.name, value: s.widgetCalendarId == cal.id ? "✓" : "") { s.widgetCalendarId = cal.id }
            }
            Text("主畫面小工具會顯示呢個行事曆嘅今日活動。").font(.caption).foregroundStyle(PT.soft).padding(.top, 8)
        }
    }
}

struct ProtoFilterSettings: View {
    @EnvironmentObject var s: ProtoState
    private let labelOptions: [(key: String, name: String, color: Color)] = [
        ("bright-orange", "Bright Orange", PT.orange),
        ("emerald", "Emerald Green", PT.green),
        ("blue", "Blue", PT.blue),
        ("red", "Red", PT.red),
        ("purple", "Purple", PT.purple),
    ]
    var body: some View {
        PSheet(title: "篩選設定", onBack: { s.screen = .settings }) {
            Text("揀咗嘅標籤先會顯示喺月曆（全部唔揀 = 全部顯示）").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            ForEach(labelOptions, id: \.key) { opt in
                Button {
                    if s.filterLabels.contains(opt.key) { s.filterLabels.remove(opt.key) }
                    else { s.filterLabels.insert(opt.key) }
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(opt.color).frame(width: 12, height: 12)
                        Text(opt.name).foregroundStyle(.primary)
                        Spacer()
                        if s.filterLabels.contains(opt.key) { Image(systemName: "checkmark").foregroundStyle(PT.orange) }
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .overlay(Divider().opacity(0.5), alignment: .bottom)
            }
            Button { s.filterLabels = []; s.screen = .settings } label: {
                Text("清除篩選").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 16)
        }
    }
}

struct ProtoNotifSettings: View {
    @EnvironmentObject var s: ProtoState
    @State private var digestDate: Date = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.date(from: "08:00") ?? Date()
    }()
    @AppStorage("notif_invite") private var notifInvite = true
    @AppStorage("notif_new_event") private var notifNewEvent = true
    @AppStorage("notif_comment") private var notifComment = true
    var body: some View {
        PSheet(title: "通知設定", onBack: { s.screen = .settings }) {
            PRow(label: "邀請", toggle: $notifInvite)
            PRow(label: "新活動", toggle: $notifNewEvent)
            PRow(label: "留言", toggle: $notifComment)
            PRow(label: "無行程嘅日子都通知", toggle: Binding(
                get: { s.api?.currentUser?.digestWhenEmpty ?? true },
                set: { v in Task { try? await s.api?.updateMePrefs(digestWhenEmpty: v) } }
            ))
            PRow(label: "只通知我有參加嘅活動", toggle: Binding(
                get: { s.api?.currentUser?.notifyOnlyMine ?? false },
                set: { v in Task { try? await s.api?.updateMePrefs(notifyOnlyMine: v) } }
            ))
            PRow(label: "活動開始前", value: "1 小時前") { s.note("提醒時間（推送功能做緊）") }
            // 每日 digest 時間（server 喺呢個鐘推「今日行程」）
            HStack {
                Text("每日通知時間")
                Spacer()
                DatePicker("", selection: $digestDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: digestDate) { _, d in
                        let f = DateFormatter(); f.dateFormat = "HH:mm"
                        Task { try? await s.api?.updateMe(digestTime: f.string(from: d)); s.note("通知時間已更新 ✓") }
                    }
            }
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
        }
        .onAppear {
            if let t = s.api?.currentUser?.digestTime {
                let f = DateFormatter(); f.dateFormat = "HH:mm"
                if let d = f.date(from: t) { digestDate = d }
            }
        }
    }
}

struct ProtoNoticeBoard: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "公告", onBack: { s.screen = .other }) {
            Button { s.screen = .noticeDetail } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("大家的評價將使 MangoTime 成長茁壯。").bold().foregroundStyle(.primary)
                    Text("For Public：歡迎喺 App Store 留個評價…").font(.caption).foregroundStyle(PT.soft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .overlay(Divider().opacity(0.5), alignment: .bottom)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text("v1.0 上線").bold()
                Text("MangoTime 正式推出！而家有 MCP、Webhook、API。").font(.caption).foregroundStyle(PT.soft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.5), alignment: .bottom)
        }
    }
}

struct ProtoNoticeDetail: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "公告", onBack: { s.screen = .noticeBoard }) {
            Text("大家的評價將使 MangoTime 成長茁壯。").font(.title3).bold().padding(.top, 12)
            Text("""
            For Public

            各位用戶好：

            如果大家鍾意 MangoTime，歡迎喺 App Store 留個評價。你哋嘅評價會幫我哋令 app 變得更好，亦會令更多人認識共享行事曆嘅好處。

            多謝支持！
            """)
            .font(.subheadline)
            .padding(.top, 10)
            Button { s.note("去評分（mock）") } label: {
                Text("去 App Store 評分").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 18)
        }
    }
}

struct ProtoPremium: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "MangoTime Premium", onBack: { s.screen = .other }) {
            VStack(spacing: 12) {
                Image(systemName: "star.fill").font(.system(size: 40)).foregroundStyle(PT.orange)
                Text("月付 HK$23.00").font(.title3).bold()
                Text("無廣告 · 上傳檔案 · 更多標籤色").font(.subheadline).foregroundStyle(PT.soft)
                Button { s.note("收費唔係而家嘅事") } label: {
                    Text("免費使用 1 個月").bold().foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.top, 30)
        }
    }
}

struct ProtoPremiumDetail: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "MangoTime Premium", onBack: { s.screen = .month }) {
            Text("什麽是 MangoTime Premium？").font(.title3).bold().padding(.top, 12)
            premiumRow(icon: "nosign", title: "無廣告", sub: "移除所有廣告，介面更乾淨")
            premiumRow(icon: "paperclip", title: "上傳檔案", sub: "活動同備忘錄可以附加 PDF、文件")
            premiumRow(icon: "tag", title: "更多標籤色", sub: "解鎖全部標籤顏色")
            premiumRow(icon: "photo.on.rectangle", title: "更大相簿", sub: "相簿容量無上限")
            if s.premium.premium {
                Label("你係 Premium 會員 ✓", systemImage: "checkmark.seal.fill").bold().foregroundStyle(PT.green)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            } else {
                Button {
                    Task { await s.premium.purchase() }
                } label: {
                    if s.premium.busy {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    } else {
                        Text("開始月付 \(s.premium.product?.displayPrice ?? "HK$23.00")").bold().foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                }
                .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(s.premium.busy)
                .padding(.top, 18)
                Button {
                    Task { await s.premium.restore() }
                } label: {
                    Text("恢復購買").font(.subheadline).foregroundStyle(PT.orange)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                Text("訂閱會自動續期，可以隨時喺 App Store 取消。").font(.caption2).foregroundStyle(PT.soft)
                    .frame(maxWidth: .infinity).padding(.top, 4)
                if s.premium.loadFailed {
                    Text("（載入唔到 App Store 產品——產品重未上架，開發中）").font(.caption2).foregroundStyle(PT.soft)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    private func premiumRow(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(PT.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(sub).font(.caption).foregroundStyle(PT.soft)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(Divider().opacity(0.5), alignment: .bottom)
    }
}
