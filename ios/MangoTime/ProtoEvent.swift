import SwiftUI
import PhotosUI

struct ProtoEventForm: View {
    @EnvironmentObject var s: ProtoState
    var editing: MTEvent? = nil
    @State private var title = ""
    @State private var saveAsMemo = false
    @State private var allDay = false
    @State private var showLabels = false
    @State private var labelIdx = 0
    @State private var date = Date()
    @State private var loc = ""
    @State private var noteText = ""
    private var labelKeys = ["bright-orange", "emerald", "blue", "red", "purple"]

    init(editing: MTEvent? = nil) {
        self.editing = editing
    }

    var body: some View {
        PSheet(title: editing == nil ? "新增活動" : "編輯活動", onBack: { s.screen = .month }, backText: "×", right: AnyView(
            Button {
                hideKeyboard()
                if s.api != nil {
                    let t = title.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    if let ev = editing {
                        Task {
                            _ = try? await s.api?.updateEvent(eventId: ev.id, title: t, startsAt: date, allDay: allDay, labelColor: labelKeys[labelIdx], location: loc.isEmpty ? nil : loc, note: noteText.isEmpty ? nil : noteText)
                            s.note("已更新 ✓")
                            await s.loadLive()
                            s.screen = .month
                        }
                    } else {
                        Task { await s.createLiveEvent(title: t, date: date, allDay: allDay, labelColor: labelKeys[labelIdx]) }
                    }
                } else {
                    s.note("已保存（mock）"); s.screen = .month
                }
            } label: {
                Text("保存").bold().foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        )) {
            TextField("標題（必填）", text: $title)
                .font(.title3).bold()
                .padding(.vertical, 12)
                .overlay(Divider(), alignment: .bottom)
                .accessibilityIdentifier("event_title")
            PRow(icon: "calendar", label: "行事曆", value: "家庭日曆") { s.note("揀行事曆（mock）") }
            PRow(icon: "doc.text", label: "儲存為備忘錄", toggle: $saveAsMemo)
            Button { showLabels.toggle() } label: {
                HStack {
                    Label("標籤", systemImage: "tag").foregroundStyle(.primary)
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
            if s.api != nil {
                DatePicker("日期", selection: $date, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                PRow(label: "全日", toggle: $allDay)
            } else {
                PRow(icon: "clock", label: "日期", value: "11月19日（週四）") { s.note("日期選擇器（mock）") }
                PRow(label: "全日", toggle: $allDay)
                if !allDay { PRow(label: "時間", value: "19:30 – 23:00") { s.note("時間選擇器（mock）") } }
            }
            PRow(icon: "repeat", label: "重複", value: "唔重複") { s.note("重複選項（mock）") }
            PRow(icon: "person.2", label: "成員", value: "全部成員") { s.note("揀成員（mock）") }
            if s.api != nil {
                HStack {
                    Label("地點", systemImage: "mappin")
                    Spacer()
                    TextField("未填", text: $loc).multilineTextAlignment(.trailing).foregroundStyle(PT.soft)
                }
                .padding(.vertical, 12).overlay(Divider().opacity(0.6), alignment: .bottom)
                HStack {
                    Label("備註", systemImage: "note.text")
                    Spacer()
                    TextField("未填", text: $noteText).multilineTextAlignment(.trailing).foregroundStyle(PT.soft)
                }
                .padding(.vertical, 12).overlay(Divider().opacity(0.6), alignment: .bottom)
            } else {
                PRow(icon: "mappin", label: "地點", value: "未填") { s.note("地點輸入（mock）") }
                PRow(icon: "link", label: "網址", value: "未填") { s.note("網址輸入（mock）") }
                PRow(icon: "note.text", label: "備註", value: "未填") { s.screen = .noteEdit }
            }
            PRow(icon: "paperclip", label: "上傳檔案", value: "＋") { s.upsell = true }
            PRow(icon: "checkmark.square", label: "待辦清單", value: "＋ 新增清單") { s.screen = .todos }
        }
        .onAppear {
            guard let ev = editing else { return }
            title = ev.title
            allDay = ev.allDay
            if let d = parseISODate(ev.startsAt) { date = d }
            if let i = labelKeys.firstIndex(of: ev.labelColor ?? "bright-orange") { labelIdx = i }
            loc = ev.location ?? ""
            noteText = ev.note ?? ""
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
            PRow(icon: "paperclip", label: "上傳檔案", value: "＋") { s.upsell = true }
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
            PRow(icon: "clock", label: "", value: "11月\(ev.day)日（週\(weekday)）\(ev.time)")
            HStack {
                Label("標籤", systemImage: "tag")
                Spacer()
                Circle().fill(ev.color).frame(width: 10, height: 10)
                Text("Bright Orange").font(.subheadline).foregroundStyle(PT.soft)
            }
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
            if !ev.loc.isEmpty { PRow(icon: "mappin", label: "地點", value: ev.loc) }
            if ev.attach > 0 { PRow(icon: "paperclip", label: "附件", value: "\(ev.attach) 個") { s.upsell = true } }
            PRow(icon: "person.2", label: "成員", value: "全部成員")
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

struct ProtoLiveEventDetail: View {
    @EnvironmentObject var s: ProtoState
    let ev: MTEvent

    private var startText: String {
        guard let d = parseISODate(ev.startsAt) else { return ev.startsAt }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_HK")
        f.dateFormat = ev.allDay ? "M月d日（E）全日" : "M月d日（E）HH:mm"
        return f.string(from: d)
    }

    var body: some View {
        PSheet(title: ev.title, onBack: { s.screen = .month }, right: AnyView(
            Button { s.screen = .editEvent(ev) } label: { Text("編輯").foregroundStyle(PT.orange) }
        )) {
            PRow(icon: "clock", label: "", value: startText)
            HStack {
                Label("標籤", systemImage: "tag")
                Spacer()
                Text(ev.labelColor ?? "bright-orange").font(.subheadline).foregroundStyle(PT.soft)
            }
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.6), alignment: .bottom)
            if let loc = ev.location, !loc.isEmpty { PRow(icon: "mappin", label: "地點", value: loc) }
            if ev.repeatRule != "none" { PRow(icon: "repeat", label: "重複", value: ev.repeatRule) }
            if let note = ev.note, !note.isEmpty { PRow(icon: "note.text", label: "備註", value: note) }
            LiveAttachments(eventId: ev.id)
            LiveChat(eventId: ev.id)
            Button {
                Task { await s.deleteLiveEvent(ev) }
            } label: {
                Text("刪除活動").bold().foregroundStyle(.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red))
            }
            .padding(.top, 18)
        }
    }
}

/// 活動附件（task 5.4）：上傳 + 顯示（相縮圖 / PDF 連結）
struct LiveAttachments: View {
    let eventId: String
    @State private var attachments: [MTAttachment] = []
    @State private var picked: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("附件", systemImage: "paperclip").font(.caption).foregroundStyle(PT.soft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(attachments) { a in
                        if a.mimeType.hasPrefix("image/") {
                            AsyncImage(url: APIClient.shared.fileURL(a.url)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color(.secondarySystemBackground) }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            VStack { Image(systemName: "doc.fill").font(.title2); Text("PDF").font(.caption2) }
                                .frame(width: 72, height: 72)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    PhotosPicker(selection: $picked, matching: .images) {
                        VStack { Image(systemName: "plus"); Text("加相").font(.caption2) }
                            .foregroundStyle(PT.orange)
                            .frame(width: 72, height: 72)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(PT.orange.opacity(0.5)))
                    }
                }
            }
        }
        .padding(.top, 12)
        .task { attachments = (try? await APIClient.shared.listAttachments(eventId: eventId)) ?? [] }
        .onChange(of: picked) { _, item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                try? await APIClient.shared.uploadAttachment(eventId: eventId, data: data, mimeType: "image/jpeg")
                attachments = (try? await APIClient.shared.listAttachments(eventId: eventId)) ?? []
                picked = nil
            }
        }
    }
}

/// 真留言（task 2.1）
struct LiveChat: View {
    let eventId: String
    @State private var comments: [MTComment] = []
    @State private var draft = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("留言").font(.caption).foregroundStyle(PT.soft)
            if comments.isEmpty {
                Text("仲未有留言").font(.caption).foregroundStyle(PT.soft)
            }
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
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty, !busy else { return }
                    busy = true
                    Task {
                        defer { busy = false }
                        if let c = try? await APIClient.shared.postComment(eventId: eventId, body: text) {
                            comments.append(c)
                            draft = ""
                        }
                    }
                } label: {
                    Text("送出").foregroundStyle(PT.orange).bold()
                }
            }
        }
        .padding(.top, 14)
        .task {
            comments = (try? await APIClient.shared.listComments(eventId: eventId)) ?? []
        }
    }
}

struct ProtoSearch: View {
    @EnvironmentObject var s: ProtoState
    @State private var q = ""
    @State private var liveResults: [MTEvent] = []
    @State private var searching = false
    var mockResults: [MockEvent] {
        q.isEmpty ? Mock.events : Mock.events.filter { $0.title.contains(q) }
    }
    var body: some View {
        PSheet(title: "搜尋活動", onBack: { s.screen = .month }) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(PT.soft)
                TextField("關鍵字…", text: $q)
                    .onSubmit { Task { await runSearch() } }
                    .onChange(of: q) { _, v in
                        if v.isEmpty { liveResults = [] }
                        else { Task { await runSearch() } }
                    }
                if searching { ProgressView() }
            }
            .padding(9).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 10)
            Text("指定行程參加者或標籤，即可篩選搜尋。")
                .font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            if s.api != nil {
                ForEach(liveResults) { ev in
                    Button { s.screen = .liveEventDetail(ev) } label: {
                        HStack(spacing: 10) {
                            Circle().fill(PT.orange).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.title).foregroundStyle(.primary)
                                Text(ev.startsAt.prefix(10)).font(.caption).foregroundStyle(PT.soft)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .overlay(Divider().opacity(0.5), alignment: .bottom)
                    }
                    .buttonStyle(.plain)
                }
                if !q.isEmpty && liveResults.isEmpty && !searching {
                    Text("搵唔到「\(q)」").font(.caption).foregroundStyle(PT.soft).padding(.top, 8)
                }
            } else {
                ForEach(mockResults) { ev in
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

    private func runSearch() async {
        guard let calId = s.activeCalendarId, !q.trimmingCharacters(in: .whitespaces).isEmpty else { liveResults = []; return }
        searching = true
        defer { searching = false }
        liveResults = (try? await s.api?.searchEvents(calendarId: calId, q: q)) ?? []
    }
}
