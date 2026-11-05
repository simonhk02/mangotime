import SwiftUI

private let wd = ["週日","週一","週二","週三","週四","週五","週六"]

struct DayCell: Identifiable {
    let id = UUID()
    let date: Date
    let other: Bool
}

func monthCells(base: Date, weekStartMonday: Bool) -> [DayCell] {
    let cal = Calendar(identifier: .gregorian)
    let comps = cal.dateComponents([.year, .month], from: base)
    let first = cal.date(from: comps)!
    let weekday = cal.component(.weekday, from: first) // 1=Sun
    let off = (weekday - (weekStartMonday ? 2 : 1) + 7) % 7
    let dim = cal.range(of: .day, in: .month, for: first)!.count
    let prevMonth = cal.date(byAdding: .month, value: -1, to: first)!
    let prevDays = cal.range(of: .day, in: .month, for: prevMonth)!.count
    var list: [DayCell] = []
    for i in stride(from: off - 1, through: 0, by: -1) {
        list.append(DayCell(date: cal.date(byAdding: .day, value: prevDays - i - 1, to: prevMonth)!, other: true))
    }
    for d in 0..<dim {
        list.append(DayCell(date: cal.date(byAdding: .day, value: d, to: first)!, other: false))
    }
    var n = 0
    while list.count % 7 != 0 {
        list.append(DayCell(date: cal.date(byAdding: .day, value: dim + n, to: first)!, other: true))
        n += 1
    }
    return list
}

struct ProtoMonthScreen: View {
    @EnvironmentObject var s: ProtoState
    private let today = Date()
    private var cal: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        VStack(spacing: 0) {
            // Apple 式大標題區：左對齊大Title + 行事曆揀選 + 操作
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(cal.component(.year, from: s.displayMonth))年\(cal.component(.month, from: s.displayMonth))月")
                        .font(.system(size: 30, weight: .bold))
                    Spacer()
                    Button { s.screen = .search } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .medium))
                            .foregroundStyle(PT.orange)
                            .frame(width: 34, height: 34)
                            .background(PT.orange.opacity(0.1)).clipShape(Circle())
                    }
                }
                HStack(spacing: 8) {
                    Button { s.screen = .calendarList } label: {
                        HStack(spacing: 5) {
                            Text(s.api != nil ? (s.liveCalendars.first(where: { $0.id == s.activeCalendarId })?.name ?? "行事曆") : "家庭日曆")
                                .font(.subheadline).bold()
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(PT.orange)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(PT.orange.opacity(0.1)).clipShape(Capsule())
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold)).foregroundStyle(PT.orange).frame(width: 30, height: 30) }
                        Button { s.displayMonth = Date() } label: { Text("今日").font(.footnote).foregroundStyle(PT.orange).frame(width: 38, height: 30) }
                        Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(PT.orange).frame(width: 30, height: 30) }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
            .background(.bar)
            Picker("", selection: Binding(get: { s.screen == .weekly ? 1 : 0 }, set: { s.screen = $0 == 1 ? .weekly : .month })) {
                Text("月曆").tag(0); Text("週曆").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 8)

            if s.screen == .month {
                ScrollView {
                    monthGrid
                }
                .refreshable { await s.loadLive() }
            } else { weekView }
        }
    }

    private var weekdays: [String] {
        s.weekStartMonday ? Array(wd[1...6]) + [wd[0]] : wd
    }

    private func shiftMonth(_ delta: Int) {
        let cal = Calendar(identifier: .gregorian)
        s.displayMonth = cal.date(byAdding: .month, value: delta, to: s.displayMonth) ?? s.displayMonth
        if s.api != nil { Task { await s.loadLive(month: s.displayMonth) } }
    }

    struct DisplayEvent: Identifiable {
        let id: String
        let title: String
        let color: Color
        let attach: Int
        let mock: MockEvent?
        let live: MTEvent?
    }

    private func labelColor(_ key: String?) -> Color {
        switch key {
        case "emerald": return PT.green
        case "blue": return PT.blue
        case "red": return PT.red
        case "purple": return PT.purple
        case "amber": return .orange
        default: return PT.orange
        }
    }

    private func eventsFor(_ cell: DayCell) -> [DisplayEvent] {
        guard !cell.other else { return [] }
        if s.api != nil {
            // LIVE：repeatRule 展開（同 web 版邏輯）+ 篩選（揀咗 label 先至顯示）
            var out = s.liveEvents.compactMap { ev -> DisplayEvent? in
                if !s.filterLabels.isEmpty && !s.filterLabels.contains(ev.labelColor ?? "bright-orange") { return nil }
                guard let start = parseISODate(ev.startsAt) else { return nil }
                let sameDay = cal.isDate(start, inSameDayAs: cell.date)
                var show = sameDay
                if !show && ev.repeatRule != "none" && start <= cell.date {
                    switch ev.repeatRule {
                    case "daily": show = true
                    case "weekly": show = cal.component(.weekday, from: start) == cal.component(.weekday, from: cell.date)
                    case "monthly": show = cal.component(.day, from: start) == cal.component(.day, from: cell.date)
                    case "yearly": show = cal.component(.day, from: start) == cal.component(.day, from: cell.date) && cal.component(.month, from: start) == cal.component(.month, from: cell.date)
                    default: break
                    }
                }
                return show ? DisplayEvent(id: ev.id, title: ev.title, color: labelColor(ev.labelColor), attach: 0, mock: nil, live: ev) : nil
            }
            // 5.1 外部日曆活動（唯讀，灰色顯示）
            for ext in s.liveExternalEvents {
                guard let start = parseISODate(ext.startsAt) else { continue }
                var show = cal.isDate(start, inSameDayAs: cell.date)
                if !show && ext.repeatRule != "none" && start <= cell.date {
                    switch ext.repeatRule {
                    case "daily": show = true
                    case "weekly": show = cal.component(.weekday, from: start) == cal.component(.weekday, from: cell.date)
                    case "monthly": show = cal.component(.day, from: start) == cal.component(.day, from: cell.date)
                    case "yearly": show = cal.component(.day, from: start) == cal.component(.day, from: cell.date) && cal.component(.month, from: start) == cal.component(.month, from: cell.date)
                    default: break
                    }
                }
                if show {
                    out.append(DisplayEvent(id: ext.id, title: ext.title, color: PT.soft, attach: 0, mock: nil, live: nil))
                }
            }
            return out
        }
        let d = cal.component(.day, from: cell.date)
        return Mock.events.filter { $0.day == d }.map {
            DisplayEvent(id: $0.id, title: $0.title, color: $0.color, attach: $0.attach, mock: $0, live: nil)
        }
    }

    private var monthGrid: some View {
        let cells = monthCells(base: s.displayMonth, weekStartMonday: s.weekStartMonday)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w).font(.system(size: 11, weight: .medium)).foregroundStyle(PT.soft).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(cells) { cell in
                    let evs = eventsFor(cell)
                    let isToday = !cell.other && cal.isDateInToday(cell.date)
                    Button {
                        if let first = evs.first {
                            if let live = first.live { s.screen = .liveEventDetail(live) }
                            else if let mock = first.mock { s.screen = .eventDetail(mock) }
                        } else { s.screen = .create }
                    } label: {
                        // Apple Calendar 式無框格：日期喺頂，活動做色 pill，冇格線
                        VStack(spacing: 3) {
                            ZStack {
                                if isToday {
                                    Circle().fill(PT.orange).frame(width: 24, height: 24)
                                }
                                Text("\(cal.component(.day, from: cell.date))")
                                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                                    .foregroundStyle(isToday ? .white : (cell.other ? PT.soft.opacity(0.6) : .primary))
                            }
                            if s.lunarOn {
                                Text(Lunar.short(cell.date))
                                    .font(.system(size: 7))
                                    .foregroundStyle(PT.soft.opacity(0.8))
                            }
                            VStack(spacing: 2) {
                                ForEach(evs.prefix(2)) { ev in
                                    Text(ev.title)
                                        .font(.system(size: 9, weight: .medium))
                                        .lineLimit(1)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(ev.color)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                if evs.count > 2 {
                                    Text("+\(evs.count - 2)")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(PT.soft)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 5)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 5).padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .top)
                        .contentShape(Rectangle())
                        .opacity(cell.other ? 0.45 : 1)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // 直向時間軸週曆：左邊 00–23 鐘，活動按時間擺位（TimeTree 直向 view）
    private let hourH: CGFloat = 42

    private func parseHour(_ time: String) -> (start: Double, end: Double)? {
        // "19:30–23:00" / "08:00–10:00" / "全日"
        if time == "全日" { return nil }
        let parts = time.replacingOccurrences(of: "–", with: "-").split(separator: "-")
        guard parts.count == 2 else { return nil }
        func h(_ s: Substring) -> Double? {
            let p = s.split(separator: ":")
            guard p.count == 2, let hh = Double(p[0]), let mm = Double(p[1]) else { return nil }
            return hh + mm / 60
        }
        guard let a = h(parts[0]), let b = h(parts[1]) else { return nil }
        return (a, b)
    }

    private func liveHour(_ ev: MTEvent) -> (start: Double, end: Double)? {
        guard let st = parseISODate(ev.startsAt) else { return nil }
        if ev.allDay { return nil }
        let start = Double(cal.component(.hour, from: st)) + Double(cal.component(.minute, from: st)) / 60
        var end = start + 1
        if let en = ev.endsAt.flatMap(parseISODate) {
            end = Double(cal.component(.hour, from: en)) + Double(cal.component(.minute, from: en)) / 60
        }
        return (start, max(end, start + 0.5))
    }

    private var weekView: some View {
        let cells = monthCells(base: s.displayMonth, weekStartMonday: s.weekStartMonday)
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: s.displayMonth)!.start
        let week = cells.filter { cal.isDate($0.date, equalTo: startOfWeek, toGranularity: .weekOfYear) }
        return ScrollView([.vertical, .horizontal], showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // 時間軸
                VStack(spacing: 0) {
                    Text("").frame(height: 26)
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d:00", h))
                            .font(.system(size: 8))
                            .foregroundStyle(PT.soft)
                            .frame(width: 34, height: hourH, alignment: .topTrailing)
                    }
                }
                // 日欄
                ForEach(week) { cell in
                    let dayEvs = eventsFor(cell)
                    VStack(spacing: 0) {
                        Text("\(wd[cal.component(.weekday, from: cell.date) - 1]) \(cal.component(.day, from: cell.date))")
                            .font(.caption2).foregroundStyle(cell.other ? PT.soft : .primary)
                            .frame(height: 26)
                        ZStack(alignment: .topLeading) {
                            // 格線
                            VStack(spacing: 0) {
                                ForEach(0..<24, id: \.self) { _ in
                                    Divider().opacity(0.4).frame(height: hourH)
                                }
                            }
                            // 全日活動（頂部細條）
                            // 定時活動按鐘擺位
                            ForEach(dayEvs) { ev in
                                if let range = ev.live != nil ? liveHour(ev.live!) : parseHour(ev.mock?.time ?? "") {
                                    Button {
                                        if let live = ev.live { s.screen = .liveEventDetail(live) }
                                        else if let mock = ev.mock { s.screen = .eventDetail(mock) }
                                    } label: {
                                        Text(ev.title)
                                            .font(.system(size: 8)).lineLimit(2)
                                            .padding(3)
                                            .frame(width: 58, height: max(20, CGFloat(range.end - range.start) * hourH), alignment: .topLeading)
                                            .background(ev.color.opacity(0.85))
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .offset(y: CGFloat(range.start) * hourH)
                                }
                            }
                        }
                        .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

struct ProtoCalendarList: View {
    @EnvironmentObject var s: ProtoState
    @State private var newName = ""
    @State private var joinCode = ""
    @State private var joinError: String?
    var body: some View {
        if s.api != nil { liveList } else { mockList }
    }

    private var liveList: some View {
        PSheet(title: "行事曆清單", onBack: { s.screen = .month }, onRefresh: { await s.loadLive() }, content: {
            VStack(spacing: 0) {
                if s.liveCalendars.isEmpty {
                    // 空態（參考圖 IMG_4684）
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus").font(.system(size: 34)).foregroundStyle(PT.soft.opacity(0.6))
                        Text("仲未有行事曆").bold()
                        Text("喺下面開你第一個行事曆，或者輸入邀請碼加入人哋嘅。").font(.subheadline).foregroundStyle(PT.soft).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                }
                ForEach(s.liveCalendars) { cal in
                    Button {
                        s.activeCalendarId = cal.id
                        Task { await s.loadLive() }
                        s.screen = .month
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(PT.orange).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cal.name).bold(cal.id == s.activeCalendarId).foregroundStyle(.primary)
                                Text("行事曆").font(.caption).foregroundStyle(PT.soft)
                            }
                            Spacer()
                            if cal.id == s.activeCalendarId { Image(systemName: "checkmark.circle.fill").foregroundStyle(PT.orange) }
                        }
                        .padding(.vertical, 10)
                        .overlay(Divider().opacity(0.5), alignment: .bottom)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
            Divider().padding(.vertical, 10)
            Text("用邀請碼加入").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                TextField("邀請碼（例如 9I7J3FIGNWK）", text: $joinCode).textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button {
                    let c = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
                    guard !c.isEmpty else { return }
                    joinError = nil
                    Task {
                        if let err = await s.joinByCode(c) { joinError = err }
                        else { joinCode = ""; s.note("已加入 ✓"); s.screen = .month }
                    }
                } label: {
                    Text("加入").bold().foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(PT.green).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if let e = joinError { Text(e).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
        }, bottom: {
            HStack {
                TextField("新行事曆名稱", text: $newName).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("cal_new_name")
                Button {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    hideKeyboard()
                    newName = ""
                    Task { await s.createLiveCalendar(name: name) }
                } label: {
                    Text("建立").bold().foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityIdentifier("cal_create_btn")
            }
        })
    }

    private var mockList: some View {
        PSheet(title: "行事曆清單", onBack: { s.screen = .month }, right: AnyView(
            Button { s.note("新增行事曆（mock）") } label: { Text("＋").foregroundStyle(PT.orange) }
        )) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(PT.soft)
                TextField("搜尋行事曆", text: .constant(""))
            }
            .padding(8).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 8)
            Picker("", selection: .constant(0)) {
                Text("全部").tag(0); Text("共享").tag(1); Text("公開").tag(2)
            }
            .pickerStyle(.segmented)
            VStack(spacing: 0) {
                calCard(name: "家庭日曆", sub: "行事曆（5）· 3 位成員", color: PT.orange, active: true)
                calCard(name: "工作", sub: "行事曆（2）· 2 位成員", color: PT.blue, active: false)
                calCard(name: "香港公眾假期", sub: "公開 · 訂閱中", color: PT.green, active: false)
            }
            .padding(.top, 8)
            Button { s.note("新增行事曆（mock）") } label: {
                Text("＋ 新增行事曆").bold().foregroundStyle(PT.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
            .padding(.top, 12)
        }
    }
    private func calCard(name: String, sub: String, color: Color, active: Bool) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).bold(.init(active))
                Text(sub).font(.caption).foregroundStyle(PT.soft)
            }
            Spacer()
            if active { Text("◎").foregroundStyle(PT.orange) }
        }
        .padding(.vertical, 10)
        .overlay(Divider().opacity(0.5), alignment: .bottom)
    }
}

struct ProtoMonthPicker: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "揀月份", onBack: { s.screen = .month }) {
            HStack {
                Text("行事曆").font(.caption).foregroundStyle(PT.soft)
                Spacer()
            }
            .padding(.top, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(1...12, id: \.self) { m in
                    Button {
                        var comps = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: s.displayMonth)
                        comps.month = m
                        comps.day = 1
                        if let d = Calendar(identifier: .gregorian).date(from: comps) {
                            s.displayMonth = d
                            if s.api != nil { Task { await s.loadLive(month: d) } }
                        }
                        s.screen = .month
                    } label: {
                        Text("\(m)月")
                            .padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(m == Calendar(identifier: .gregorian).component(.month, from: s.displayMonth) ? PT.orange.opacity(0.15) : Color(.secondarySystemBackground))
                            .foregroundStyle(m == Calendar(identifier: .gregorian).component(.month, from: s.displayMonth) ? PT.orange : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}
