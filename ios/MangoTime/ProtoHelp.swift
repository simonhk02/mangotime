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
                        Image(systemName: c.icon).foregroundStyle(PT.orange)
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
    @State private var category = "功能問題"
    @State private var body_ = ""
    @State private var sent = false
    @State private var sending = false
    private let categories = ["功能問題", "帳戶/登入", "建議", "其他"]
    var body: some View {
        PSheet(title: "詢問客服", onBack: { s.screen = .other }) {
            if sent {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(PT.green)
                    Text("已收到你嘅問題！").bold()
                    Text("我哋會用 email 覆你（\(s.api?.currentUser?.email ?? "")）。").font(.caption).foregroundStyle(PT.soft).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                Text("為了更快解決問題，請講清楚你遇到嘅情況。")
                    .font(.caption).foregroundStyle(PT.soft)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                // 類別 chips
                FlowRow(spacing: 8) {
                    ForEach(categories, id: \.self) { c in
                        FilterChip(text: c, active: category == c) { category = c }
                    }
                }
                TextEditor(text: $body_)
                    .frame(minHeight: 140)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                    .padding(.top, 10)
                Button {
                    guard !body_.trimmingCharacters(in: .whitespaces).isEmpty else { s.note("寫低你嘅問題先"); return }
                    sending = true
                    Task {
                        let ok = (try? await s.api?.sendSupport(category: category, body: body_)) ?? false
                        sending = false
                        sent = true
                        if !ok { s.note("已收到（email 通道未開通，會用站內通知跟進）") }
                    }
                } label: {
                    if sending {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                    } else {
                        Text("送出").bold().foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
                .background(PT.orange).clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(sending)
                .padding(.top, 16)
            }
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
            storyRow(icon: "photo", title: "一家人嘅行程表", sub: "家庭 · 3 位成員")
            storyRow(icon: "photo", title: "小公司嘅班表", sub: "工作 · 8 位成員")
            storyRow(icon: "tennis.racket", title: "波友嘅訂場曆", sub: "興趣 · 12 位成員")
        }
    }
    private func storyRow(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(PT.soft)
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
