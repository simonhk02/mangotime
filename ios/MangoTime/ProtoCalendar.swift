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
            PNavBar("\(cal.component(.year, from: today))年\(cal.component(.month, from: today))月 ～", left: {
                Button { s.screen = .calendarList } label: {
                    Text("家庭日曆 ▾").font(.subheadline).foregroundStyle(PT.orange)
                }
            }, right: {
                HStack(spacing: 14) {
                    Button { s.screen = .search } label: { Image(systemName: "magnifyingglass").foregroundStyle(PT.orange) }
                    Button { s.screen = .monthPicker } label: { Image(systemName: "calendar").foregroundStyle(PT.orange) }
                }
            })
            Button { s.screen = .premiumDetail } label: {
                HStack {
                    Text("⭐ TimeTree Premium").font(.caption).bold()
                    Spacer()
                    Text("無廣告・上傳檔案 ›").font(.caption).foregroundStyle(PT.soft)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }
            .buttonStyle(.plain)
            Picker("", selection: Binding(get: { s.screen == .weekly ? 1 : 0 }, set: { s.screen = $0 == 1 ? .weekly : .month })) {
                Text("月曆").tag(0); Text("週曆").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14).padding(.vertical, 6)

            if s.screen == .month { monthGrid } else { weekView }
        }
    }

    private var weekdays: [String] {
        s.weekStartMonday ? Array(wd[1...6]) + [wd[0]] : wd
    }

    private func eventsFor(_ cell: DayCell) -> [MockEvent] {
        guard !cell.other else { return [] }
        let d = cal.component(.day, from: cell.date)
        return Mock.events.filter { $0.day == d }
    }

    private var monthGrid: some View {
        let cells = monthCells(base: today, weekStartMonday: s.weekStartMonday)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w).font(.caption2).foregroundStyle(PT.soft).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 5)
            Divider()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(cells) { cell in
                    let evs = eventsFor(cell)
                    let isToday = !cell.other && cal.isDateInToday(cell.date)
                    Button {
                        if let ev = evs.first { s.screen = .eventDetail(ev) } else { s.screen = .create }
                    } label: {
                        VStack(spacing: 1) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(cal.component(.day, from: cell.date))")
                                    .font(.system(size: 13, weight: isToday ? .bold : .medium))
                                    .foregroundStyle(isToday ? PT.orange : .primary)
                                if s.lunarOn {
                                    Text(Lunar.short(cell.date))
                                        .font(.system(size: 7))
                                        .foregroundStyle(PT.soft)
                                }
                            }
                            ForEach(evs.prefix(2)) { ev in
                                Text(ev.title + (ev.attach > 0 ? " 📎\(ev.attach)" : ""))
                                    .font(.system(size: 8))
                                    .lineLimit(1)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(ev.color)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 3).padding(.horizontal, 2)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .top)
                        .background(isToday ? PT.orange.opacity(0.08) : Color(.systemBackground))
                        .overlay(Rectangle().stroke(Color(.separator).opacity(0.4), lineWidth: 0.4))
                        .opacity(cell.other ? 0.35 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weekView: some View {
        let cells = monthCells(base: today, weekStartMonday: s.weekStartMonday)
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: today)!.start
        let week = cells.filter { cal.isDate($0.date, equalTo: startOfWeek, toGranularity: .weekOfYear) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(week) { cell in
                    VStack(spacing: 4) {
                        Text("\(wd[cal.component(.weekday, from: cell.date) - 1]) \(cal.component(.day, from: cell.date))")
                            .font(.caption2).foregroundStyle(PT.soft)
                        ForEach(eventsFor(cell)) { ev in
                            Text(ev.title).font(.system(size: 9)).lineLimit(1)
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ev.color).foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .onTapGesture { s.screen = .eventDetail(ev) }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(5)
                    .frame(width: 110, height: 300)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 10)
        }
    }
}

struct ProtoCalendarList: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
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
                calCard(name: "家庭日曆", sub: "行事曆（5）· 👥 3", color: PT.orange, active: true)
                calCard(name: "工作", sub: "行事曆（2）· 👥 2", color: PT.blue, active: false)
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
                    Button { s.note("跳去 \(m) 月（mock）"); s.screen = .month } label: {
                        Text("\(m)月")
                            .padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(m == 11 ? PT.orange.opacity(0.15) : Color(.secondarySystemBackground))
                            .foregroundStyle(m == 11 ? PT.orange : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}
