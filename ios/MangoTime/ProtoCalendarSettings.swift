import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins

/// 行事曆設定（TimeTree「行事曆設定」頁）：封面圖、改名、公開連結+QR、刪除
struct ProtoCalendarSettings: View {
    @EnvironmentObject var s: ProtoState
    let cal: MTCalendar
    @State private var name: String = ""
    @State private var coverItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var publicSlug: String? = nil
    @State private var confirmDelete = false
    @State private var stats: MTPublicStats? = nil
    @State private var noindex = false
    @State private var showBulk = false
    @State private var bulkText = ""

    var body: some View {
        PSheet(title: "行事曆設定", onBack: { s.screen = .calendarList }) {
            // 封面
            VStack(spacing: 8) {
                if let urlStr = cal.coverImageUrl, let url = URL(string: (s.api?.baseURL ?? "") + urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color(.secondarySystemBackground)
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 120)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)).frame(height: 120)
                        Image(systemName: "photo").font(.title2).foregroundStyle(PT.soft)
                    }
                }
                PhotosPicker(selection: $coverItem, matching: .images) {
                    Text(uploading ? "上傳緊…" : "更換封面圖").font(.subheadline).foregroundStyle(PT.orange)
                }
                .onChange(of: coverItem) { _, item in
                    guard let item else { return }
                    Task {
                        uploading = true
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            let mime = data.count > 8 && data.prefix(4).elementsEqual([0x89, 0x50, 0x4e, 0x47]) ? "image/png" : "image/jpeg"
                            try? await s.api?.uploadCover(calendarId: cal.id, data: data, mimeType: mime)
                            await s.loadLive()
                            s.note("封面已更新 ✓")
                        }
                        uploading = false
                    }
                }
            }
            .padding(.top, 10)

            // 改名
            PCard {
                HStack {
                    Text("名稱")
                    Spacer()
                    TextField("行事曆名稱", text: $name).multilineTextAlignment(.trailing).foregroundStyle(PT.soft)
                }
                .padding(.vertical, 12)
                Button {
                    Task {
                        try? await s.api?.renameCalendar(id: cal.id, name: name)
                        await s.loadLive()
                        s.note("已改名 ✓")
                    }
                } label: {
                    Text("保存名稱").bold().foregroundStyle(PT.orange)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)

            // 公開連結 + QR
            PCard {
                HStack {
                    Image(systemName: "globe").foregroundStyle(PT.soft).frame(width: 20)
                    Text("公開連結")
                    Spacer()
                    if publicSlug == nil {
                        Button {
                            Task {
                                publicSlug = try? await s.api?.enablePublic(calendarId: cal.id)
                                await s.loadLive()
                            }
                        } label: { Text("開啟").bold().foregroundStyle(PT.orange) }
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(PT.green)
                    }
                }
                .padding(.vertical, 12)
                if let slug = publicSlug ?? cal.publicSlug {
                    let url = "https://mangotime.149-28-154-219.sslip.io/public/\(slug)"
                    VStack(spacing: 10) {
                        // QR code（畀管理者印海報用）
                        if let qr = qrImage(for: url) {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable().scaledToFit()
                                .frame(width: 140, height: 140)
                        }
                        Text(url).font(.caption2).foregroundStyle(PT.soft)
                            .lineLimit(1).truncationMode(.middle)
                        ShareLink(item: url) {
                            Label("分享連結", systemImage: "square.and.arrow.up").font(.subheadline).foregroundStyle(PT.orange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .padding(.top, 14)

            // 公開管理者（有開公開連結先顯示）
            if publicSlug ?? cal.publicSlug != nil {
                PCard {
                    HStack {
                        Image(systemName: "chart.bar").foregroundStyle(PT.soft).frame(width: 20)
                        Text("公開管理").bold()
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    if let st = stats {
                        HStack(spacing: 14) {
                            VStack { Text("\(st.likeCount)").bold(); Text("讚").font(.caption2).foregroundStyle(PT.soft) }
                            VStack { Text("\(st.copyCount)").bold(); Text("抄入").font(.caption2).foregroundStyle(PT.soft) }
                            VStack { Text("\(st.eventCount)").bold(); Text("活動").font(.caption2).foregroundStyle(PT.soft) }
                            VStack { Text("\(st.memberCount)").bold(); Text("成員").font(.caption2).foregroundStyle(PT.soft) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    PRow(label: "唔俾搜尋引擎收錄", toggle: Binding(
                        get: { noindex },
                        set: { v in
                            noindex = v
                            Task { try? await s.api?.setNoindex(calendarId: cal.id, noindex: v) }
                        }
                    ))
                    Button { showBulk.toggle() } label: {
                        HStack {
                            Image(systemName: "square.stack").foregroundStyle(PT.soft).frame(width: 20)
                            Text("批次登錄活動").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: showBulk ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(PT.soft)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if showBulk {
                        Text("每行一個：標題 | 日期(YYYY-MM-DD) | 時間(HH:MM 可留空)")
                            .font(.caption2).foregroundStyle(PT.soft)
                        TextEditor(text: $bulkText)
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator)))
                        Button {
                            let events = parseBulk(bulkText)
                            guard !events.isEmpty else { s.note("格式唔啱"); return }
                            Task {
                                if let n = try? await s.api?.bulkCreateEvents(calendarId: cal.id, events: events) {
                                    s.note("已建立 \(n) 個活動 ✓")
                                    bulkText = ""
                                    await s.loadLive()
                                } else { s.note("批次失敗") }
                            }
                        } label: {
                            Text("一次過建立").bold().foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 14)
            }

            // 刪除
            Button { confirmDelete = true } label: {
                Text("刪除行事曆").bold().foregroundStyle(.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 18)
            .alert("刪除「\(cal.name)」？", isPresented: $confirmDelete) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    Task {
                        try? await s.api?.deleteCalendar(id: cal.id)
                        s.activeCalendarId = nil
                        await s.loadLive()
                        s.screen = .calendarList
                        s.note("已刪除")
                    }
                }
            } message: {
                Text("行事曆入面所有活動、留言、附件會一齊刪除，冇得還原。")
            }
        }
        .onAppear {
            name = cal.name
            if let slug = publicSlug ?? cal.publicSlug {
                Task {
                    stats = try? await s.api?.publicStats(calendarId: cal.id)
                    noindex = stats?.noindex ?? false
                }
            }
        }
    }

    private func qrImage(for string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}


/// "標題 | 2026-11-20 | 19:00" 逐行 parse
private func parseBulk(_ bulk: String) -> [[String: String]] {
    bulk.split(separator: "\n").compactMap { line in
        let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, !parts[0].isEmpty else { return nil }
        var ev: [String: String] = ["title": parts[0]]
        ev["startsAt"] = parts.count >= 3 && !parts[2].isEmpty ? "\(parts[1])T\(parts[2]):00+08:00" : "\(parts[1])T00:00:00+08:00"
        if parts.count < 3 || parts[2].isEmpty { ev["allDay"] = "true" }
        return ev
    }
}
