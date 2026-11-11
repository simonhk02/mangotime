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
        .onAppear { name = cal.name }
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
