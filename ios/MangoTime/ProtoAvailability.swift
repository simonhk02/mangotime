import SwiftUI

/// 「將有空的日期以圖片方式共享」（TimeTree 招牌）：揀今個星期邊啲日子有空 → 生成圖片 → ShareLink
struct ProtoAvailability: View {
    @EnvironmentObject var s: ProtoState
    @State private var picked: Set<Date> = []
    private let cal = Calendar(identifier: .gregorian)

    private var weekDays: [Date] {
        let start = cal.dateInterval(of: .weekOfYear, for: Date())!.start
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func events(on d: Date) -> [MTEvent] {
        s.liveEvents.filter { ev in
            guard let start = parseISODate(ev.startsAt) else { return false }
            return cal.isDate(start, inSameDayAs: d)
        }
    }

    var body: some View {
        PSheet(title: "分享有空嘅日子", onBack: { s.screen = .other }) {
            Text("揀你想話俾人知有空嘅日子，生成圖片分享。")
                .font(.caption).foregroundStyle(PT.soft).padding(.top, 8)
            ForEach(weekDays, id: \.self) { d in
                let evs = events(on: d)
                let free = evs.isEmpty
                Button {
                    if picked.contains(d) { picked.remove(d) } else { picked.insert(d) }
                } label: {
                    HStack {
                        Image(systemName: picked.contains(d) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(picked.contains(d) ? PT.orange : PT.soft)
                        Text(d, format: .dateTime.month().day().weekday(.abbreviated))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(free ? "全日有空" : "\(evs.count) 個活動")
                            .font(.caption).foregroundStyle(free ? PT.green : PT.soft)
                    }
                    .padding(.vertical, 11)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }

            if !picked.isEmpty {
                AvailabilityCard(days: picked.sorted(), calName: s.liveCalendars.first(where: { $0.id == s.activeCalendarId })?.name ?? "")
                    .padding(.top, 16)
                ShareLink(item: Image(uiImage: renderCard()), preview: SharePreview("我有空嘅日子", image: Image(uiImage: renderCard()))) {
                    Label("分享圖片", systemImage: "square.and.arrow.up").bold().foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 12)
            }
        }
    }

    @MainActor private func renderCard() -> UIImage {
        let renderer = ImageRenderer(content: AvailabilityCard(days: picked.sorted(), calName: s.liveCalendars.first(where: { $0.id == s.activeCalendarId })?.name ?? ""))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

/// 分享出去嗰張卡
struct AvailabilityCard: View {
    let days: [Date]
    let calName: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("我有空嘅日子").font(.title3).bold()
                Spacer()
                Text("MangoTime").font(.caption).bold().foregroundStyle(.orange)
            }
            if !calName.isEmpty { Text(calName).font(.caption).foregroundStyle(.secondary) }
            ForEach(days, id: \.self) { d in
                HStack {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text(d, format: .dateTime.month().day().weekday(.wide))
                }
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
