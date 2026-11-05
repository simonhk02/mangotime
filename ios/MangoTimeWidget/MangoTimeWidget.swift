import WidgetKit
import SwiftUI

/// MangoTime widget：今日活動（由 app 經 App Group 同步快取，widget 唔直接打 API）
struct MTEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEvent]
    let calendarName: String
    let loggedIn: Bool
}

struct WidgetEvent: Identifiable, Codable {
    let id: String
    let title: String
    let time: String
    let colorHex: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MTEntry {
        MTEntry(date: Date(), events: [.init(id: "1", title: "屋企人飯局", time: "19:00", colorHex: "#FF7043")], calendarName: "家庭日曆", loggedIn: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (MTEntry) -> Void) {
        completion(load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MTEntry>) -> Void) {
        let entry = load()
        // 每 15 分鐘 refresh
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> MTEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.mangotime.app"),
              let data = defaults.data(forKey: "widget_today"),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return MTEntry(date: Date(), events: [], calendarName: "MangoTime", loggedIn: false)
        }
        return MTEntry(date: Date(), events: snap.events, calendarName: snap.calendarName, loggedIn: true)
    }
}

struct WidgetSnapshot: Codable {
    let calendarName: String
    let events: [WidgetEvent]
}

struct MangoTimeWidgetEntryView: View {
    var entry: MTEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.calendarName).font(.caption).bold().foregroundStyle(Color(hex: "#FF7043"))
                Spacer()
                Text("今日").font(.caption2).foregroundStyle(.secondary)
            }
            if !entry.loggedIn {
                Spacer()
                Text("開 app 登入先").font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else if entry.events.isEmpty {
                Spacer()
                Text("今日冇活動").font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.events.prefix(4)) { ev in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: ev.colorHex)).frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ev.title).font(.caption2).bold().lineLimit(1)
                            Text(ev.time).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if h.count == 6 { h += "FF" }
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(.sRGB, red: Double((n >> 24) & 0xff) / 255, green: Double((n >> 16) & 0xff) / 255, blue: Double((n >> 8) & 0xff) / 255, opacity: Double(n & 0xff) / 255)
    }
}

@main
struct MangoTimeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MangoTimeWidget", provider: Provider()) { entry in
            MangoTimeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日活動")
        .description("MangoTime 行事曆今日嘅活動一覽")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
