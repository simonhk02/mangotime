import SwiftUI

struct ProtoHelpHome: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "使用方法", onBack: { s.screen = .settings }) {
            Text("給初次使用者").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            ForEach(Mock.helpCats) { c in
                Button { s.screen = .helpCategory(c) } label: {
                    HStack(spacing: 12) {
                        Text(c.icon)
                        Text(c.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                    }
                    .padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProtoHelpCategory: View {
    @EnvironmentObject var s: ProtoState
    let cat: HelpCat
    var body: some View {
        PSheet(title: cat.name, onBack: { s.screen = .helpHome }) {
            ForEach(cat.arts, id: \.self) { a in
                Button { s.screen = .helpArticle(a) } label: {
                    HStack {
                        Text(a).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                    }
                    .padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProtoHelpArticle: View {
    @EnvironmentObject var s: ProtoState
    let article: String
    var body: some View {
        PSheet(title: article, onBack: { s.screen = .helpHome }) {
            Text(article).font(.headline).padding(.top, 12)
            let body = Mock.articleBody[article] ?? ["呢篇文章嘅內容（mock）。"]
            ForEach(body, id: \.self) { line in
                Text(line).font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            HStack(spacing: 16) {
                Button { s.note("多謝意見（mock）") } label: {
                    Label("有幫助", systemImage: "hand.thumbsup")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                }
                Button { s.note("多謝意見（mock）") } label: {
                    Label("冇幫助", systemImage: "hand.thumbsdown")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                }
            }
            .padding(.top, 20)
            .foregroundStyle(.primary)
        }
    }
}

struct ProtoFAQ: View {
    @EnvironmentObject var s: ProtoState
    private let faqs = [
        "我要如何更換手機？",
        "行程未被共享",
        "小工具未顯示行程",
        "想使用其他日曆（例如 Google 日曆）",
        "我要刪除帳號／退出服務",
    ]
    var body: some View {
        PSheet(title: "常見問題", onBack: { s.screen = .settings }) {
            Text("MangoTime 常見問題集").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            ForEach(faqs, id: \.self) { q in
                Button { s.screen = .helpArticle(q.replacingOccurrences(of: "我要如何更換手機？", with: "因變更機型而希望繼承數據")) } label: {
                    HStack {
                        Text("• \(q)").foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                    }
                    .padding(.vertical, 12)
                    .overlay(Divider().opacity(0.5), alignment: .bottom)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProtoContact: View {
    @EnvironmentObject var s: ProtoState
    @State private var category = "Please select a category."
    @State private var body_ = ""
    var body: some View {
        PSheet(title: "詢問", onBack: { s.screen = .settings }) {
            Text("請使用英文與我們聯繫。為了更快解決問題，請提供你嘅行事曆 ID 同埋問題截圖。")
                .font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            PRow(label: "類別", value: category) { s.note("揀類別（mock）") }
            TextEditor(text: $body_)
                .frame(minHeight: 140)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                .padding(.top, 10)
            Button { s.note("已送出（mock）") } label: {
                Text("送出").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 16)
        }
    }
}

struct ProtoUserGuide: View {
    @EnvironmentObject var s: ProtoState
    var body: some View {
        PSheet(title: "樹民的使用手冊", onBack: { s.screen = .other }) {
            Text("MangoTime User Stories").font(.title3).bold().padding(.top, 12)
            Text("Browse 樹民們點樣用共享行事曆：").font(.caption).foregroundStyle(PT.soft)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
            storyRow(emoji: "👨‍👩‍👧", title: "一家人嘅行程表", sub: "家庭 · 3 位成員")
            storyRow(emoji: "🏢", title: "小公司嘅班表", sub: "工作 · 8 位成員")
            storyRow(emoji: "🎾", title: "波友嘅訂場曆", sub: "興趣 · 12 位成員")
        }
    }
    private func storyRow(emoji: String, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title2)
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
