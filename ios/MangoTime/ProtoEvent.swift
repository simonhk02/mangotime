import SwiftUI

struct ProtoEventForm: View {
    @EnvironmentObject var s: ProtoState
    @State private var title = "打邊爐"
    @State private var saveAsMemo = false
    @State private var allDay = false
    @State private var showLabels = false
    @State private var labelIdx = 0
    var body: some View {
        PSheet(title: "新增活動", onBack: { s.screen = .month }, backText: "×", right: AnyView(
            Button { s.note("已保存（mock）"); s.screen = .month } label: {
                Text("保存").bold().foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        )) {
            TextField("標題（必填）", text: $title)
                .font(.title3).bold()
                .padding(.vertical, 12)
                .overlay(Divider(), alignment: .bottom)
            PRow(label: "📅 行事曆", value: "家庭日曆") { s.note("揀行事曆（mock）") }
            PRow(label: "📄 儲存為備忘錄", toggle: $saveAsMemo)
            Button { showLabels.toggle() } label: {
                HStack {
                    Text("🏷 標籤").foregroundStyle(.primary)
                    Spacer()
                    Circle().fill(Mock.labels[labelIdx].1).frame(width: 10, height: 10)
                    Text(Mock.labels[labelIdx].0).font(.subheadline).foregroundStyle(PT.soft)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
            if showLabels {
                VStack(spacing: 0) {
                    ForEach(Array(Mock.labels.enumerated()), id: \.offset) { i, l in
                        Button { labelIdx = i; showLabels = false } label: {
                            HStack(spacing: 10) {
                                Circle().fill(l.1).frame(width: 12, height: 12)
                                Text(l.0).foregroundStyle(.primary)
                                Spacer()
                                if i == labelIdx { Image(systemName: "checkmark").foregroundStyle(PT.orange) }
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            PRow(label: "🕐 日期", value: "11月19日（週四）") { s.note("日期選擇器（mock）") }
            PRow(label: "全日", toggle: $allDay)
            if !allDay { PRow(label: "時間", value: "19:30 – 23:00") { s.note("時間選擇器（mock）") } }
            PRow(label: "🔁 重複", value: "唔重複") { s.note("重複選項（mock）") }
            PRow(label: "👥 成員", value: "全部成員") { s.note("揀成員（mock）") }
            PRow(label: "📍 地點", value: "未填") { s.note("地點輸入（mock）") }
            PRow(label: "🔗 網址", value: "未填") { s.note("網址輸入（mock）") }
            PRow(label: "🗒 備註", value: "未填") { s.screen = .noteEdit }
            PRow(label: "📎 上傳檔案", value: "＋") { s.upsell = true }
            PRow(label: "☑ 待辦清單", value: "＋ 新增清單") { s.screen = .todos }
        }
    }
}

struct ProtoNoteEdit: View {
    @EnvironmentObject var s: ProtoState
    @State private var text = "記得買沙茶醬、出前一丁\n青菜兩款"
    var body: some View {
        PSheet(title: "備註", onBack: { s.screen = .create }, right: AnyView(
            Button { s.note("已保存（mock）"); s.screen = .create } label: { Text("保存").bold().foregroundStyle(PT.orange) }
        )) {
            TextEditor(text: $text)
                .frame(minHeight: 160)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                .padding(.top, 10)
            PRow(label: "📎 上傳檔案", value: "＋") { s.upsell = true }
        }
    }
}

struct ProtoEventDetail: View {
    @EnvironmentObject var s: ProtoState
    let ev: MockEvent
    private var weekday: String {
        ["日","一","二","三","四","五","六"][Calendar(identifier: .gregorian).component(.weekday, from: {
            var c = DateComponents(); c.year = 2026; c.month = 11; c.day = ev.day
            return Calendar(identifier: .gregorian).date(from: c)!
        }()) - 1]
    }
    var body: some View {
        PSheet(title: ev.title, onBack: { s.screen = .month }, right: AnyView(
            Button { s.note("編輯（mock）") } label: { Text("編輯").foregroundStyle(PT.orange) }
        )) {
            PRow(label: "🕐", value: "11月\(ev.day)日（週\(weekday)）\(ev.time)")
            HStack {
                Text("🏷 標籤")
                Spacer()
                Circle().fill(ev.color).frame(width: 10, height: 10)
                Text("Bright Orange").font(.subheadline).foregroundStyle(PT.soft)
            }
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
            if !ev.loc.isEmpty { PRow(label: "📍 地點", value: ev.loc) }
            if ev.attach > 0 { PRow(label: "📎 附件", value: "\(ev.attach) 個") { s.upsell = true } }
            PRow(label: "👥 成員", value: "全部成員")
            ChatBox(msgs: [("老婆", "買緊嘢食，要乜？", false), ("我", "沙茶醬幫手攞支", true)])
            Button { s.note("已刪除（mock）"); s.screen = .month } label: {
                Text("刪除活動").bold().foregroundStyle(.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red))
            }
            .padding(.top, 18)
        }
    }
}

struct ProtoSearch: View {
    @EnvironmentObject var s: ProtoState
    @State private var q = ""
    var results: [MockEvent] {
        q.isEmpty ? Mock.events : Mock.events.filter { $0.title.contains(q) }
    }
    var body: some View {
        PSheet(title: "搜尋活動", onBack: { s.screen = .month }) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(PT.soft)
                TextField("關鍵字…", text: $q)
            }
            .padding(9).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 10)
            Text("指定行程參加者或標籤，即可篩選搜尋。")
                .font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            ForEach(results) { ev in
                Button { s.screen = .eventDetail(ev) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(ev.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ev.title).foregroundStyle(.primary)
                            Text("11月\(ev.day)日 \(ev.time)").font(.caption).foregroundStyle(PT.soft)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
