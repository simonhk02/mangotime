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
            PRow(label: "🖥 顯示設定") { s.screen = .displaySettings }
            PRow(label: "🔍 篩選設定") { s.screen = .filterSettings }
            Text("通知").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
            PRow(label: "🔔 通知設定") { s.screen = .notifSettings }
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
            PRow(label: "📢 公告") { s.screen = .noticeBoard }
            PRow(label: "📖 樹民的使用手冊") { s.screen = .userGuide }
            PRow(label: "❓ 使用方法") { s.screen = .helpHome }
            PRow(label: "🙋 常見問題") { s.screen = .faq }
            PRow(label: "✉️ 詢問") { s.screen = .contact }
            Text("社群").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
            PRow(label: "🌐 官方網站") { s.note("網站（mock）") }
            PRow(label: "🐦 X / Twitter") { s.note("X（mock）") }
            PRow(label: "⭐ 喺 App Store 評分") { s.note("評分（mock）") }
        }
    }
}

struct ProtoDisplaySettings: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "顯示設定", onBack: { s.screen = .settings }) {
            PRow(label: "一週嘅開始", value: s.weekStartMonday ? "週一" : "週日") { s.weekStartMonday.toggle() }
            PRow(label: "農曆顯示", toggle: $s.lunarOn)
            PRow(label: "第幾週", toggle: .constant(false))
            PRow(label: "節日", value: "香港") { s.note("節日（mock）") }
            PRow(label: "24 小時制", toggle: .constant(true))
            PRow(label: "行事曆顯示") { s.screen = .displayCalendar }
        }
    }
}

struct ProtoDisplayCalendar: View {
    @EnvironmentObject var s: ProtoState
    @State private var on = ["家庭日曆": true, "工作": true, "香港公眾假期": false]
    var body: some View {
        PSheet(title: "行事曆顯示", onBack: { s.screen = .displaySettings }) {
            PRow(label: "家庭日曆", toggle: binding("家庭日曆"))
            PRow(label: "工作", toggle: binding("工作"))
            PRow(label: "香港公眾假期", toggle: binding("香港公眾假期"))
            Text("隱藏嘅行事曆唔會喺月曆顯示。").font(.caption).foregroundStyle(PT.soft).padding(.top, 8)
        }
    }
    private func binding(_ key: String) -> Binding<Bool> {
        Binding(get: { on[key] ?? false }, set: { on[key] = $0 })
    }
}

struct ProtoFilterSettings: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "篩選設定", onBack: { s.screen = .settings }) {
            Text("指定行程參加者或標籤，即可篩選。").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            PRow(label: "👥 參加者", value: "全部") { s.note("揀參加者（mock）") }
            PRow(label: "🏷 標籤", value: "全部") { s.note("揀標籤（mock）") }
            Button { s.note("已套用（mock）"); s.screen = .settings } label: {
                Text("套用").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 16)
        }
    }
}

struct ProtoNotifSettings: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "通知設定", onBack: { s.screen = .settings }) {
            PRow(label: "邀請", toggle: .constant(true))
            PRow(label: "新活動", toggle: .constant(true))
            PRow(label: "留言", toggle: .constant(true))
            PRow(label: "活動開始前", value: "1 小時前") { s.note("提醒時間（mock）") }
            PRow(label: "每日通知時間", value: "09:00") { s.note("通知時間（mock）") }
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
                Text("v1.0 上線 🎉").bold()
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
                Text("⭐").font(.system(size: 48))
                Text("月付 HK$23.00").font(.title3).bold()
                Text("無廣告 · 上傳檔案 · 更多標籤色").font(.subheadline).foregroundStyle(PT.soft)
                Button { s.note("收費唔係而家嘅事 😄") } label: {
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
            premiumRow(icon: "🚫", title: "無廣告", sub: "移除所有廣告，介面更乾淨")
            premiumRow(icon: "📎", title: "上傳檔案", sub: "活動同備忘錄可以附加 PDF、文件")
            premiumRow(icon: "🏷", title: "更多標籤色", sub: "解鎖全部標籤顏色")
            premiumRow(icon: "🖼", title: "更大相簿", sub: "相簿容量無上限")
            Button { s.note("收費唔係而家嘅事 😄") } label: {
                Text("開始月付 HK$23.00").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 18)
            Text("免費使用 1 個月，之後每月 HK$23.00").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity).padding(.top, 6)
        }
    }
    private func premiumRow(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            Text(icon).font(.title2)
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
