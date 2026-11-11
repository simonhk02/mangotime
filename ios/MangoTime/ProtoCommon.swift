import SwiftUI

/// 簡單換行 layout：chips 太多時自動跌落下一行
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > w, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// 篩選 chip（搜尋/篩選設定用）：撳切換，active 填橙色
struct FilterChip: View {
    let text: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption).bold()
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(active ? .white : .primary)
                .background(active ? PT.orange : Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Apple 式撳掣微縮放（撳落去 0.96，放手彈返）
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// iOS 設定式圓角卡片（一組 row 包埋一齊）
struct PCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// 自家製 MangoTime logo（純 SwiftUI，唔使圖檔）：橙色芒果身 + 綠葉
struct MangoLogo: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 葉
            Ellipse()
                .fill(PT.green)
                .frame(width: size * 0.28, height: size * 0.14)
                .rotationEffect(.degrees(-30))
                .offset(x: size * 0.12, y: -size * 0.04)
            // 芒果身
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.62, blue: 0.35), PT.orange],
                        center: .topLeading, startRadius: 0, endRadius: size
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(x: 0.92, y: 1.0)
            // 高光
            Ellipse()
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.22, height: size * 0.12)
                .rotationEffect(.degrees(-25))
                .offset(x: -size * 0.2, y: size * 0.16)
        }
        .frame(width: size, height: size * 1.05)
        .accessibilityLabel("MangoTime logo")
    }
}

/// 原型共用件
struct PNavBar<Left: View, Right: View>: View {
    let title: String
    let left: Left
    let right: Right
    init(_ title: String, @ViewBuilder left: () -> Left = { EmptyView() }, @ViewBuilder right: () -> Right = { EmptyView() }) {
        self.title = title; self.left = left(); self.right = right()
    }
    var body: some View {
        HStack {
            left.frame(minWidth: 70, alignment: .leading)
            Spacer()
            Text(title).font(.headline)
            Spacer()
            right.frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct PRow: View {
    var icon: String? = nil
    let label: String
    var value: String = ""
    var valueColor: Color = PT.soft
    var toggle: Binding<Bool>? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        Button {
            if let t = toggle { t.wrappedValue.toggle() } else { action?() }
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(PT.soft)
                        .frame(width: 20)
                }
                Text(label).foregroundStyle(.primary)
                Spacer()
                if let t = toggle {
                    Toggle("", isOn: t).labelsHidden().tint(PT.green)
                } else if !value.isEmpty {
                    Text(value).font(.subheadline).foregroundStyle(valueColor)
                }
                if action != nil && toggle == nil {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PT.soft)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .overlay(Divider().opacity(0.6), alignment: .bottom)
    }
}

struct PSheet<Content: View, Bottom: View>: View {
    let title: String
    var onBack: () -> Void
    var backText: String = "‹"
    var right: AnyView? = nil
    var onRefresh: (() async -> Void)? = nil
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom
    var body: some View {
        VStack(spacing: 0) {
            PNavBar(title, left: {
                Button(action: onBack) { Text(backText).font(.title3).foregroundStyle(PT.orange) }
            }, right: { right })
            if let onRefresh {
                ScrollView {
                    VStack(spacing: 0) { content }.padding(.horizontal, 16)
                }
                .refreshable { await onRefresh() }
            } else {
                ScrollView {
                    VStack(spacing: 0) { content }.padding(.horizontal, 16)
                }
            }
            bottom
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .top)
        }
    }
}

// 冇 bottom bar 嘅版本（向後兼容）
extension PSheet where Bottom == EmptyView {
    init(title: String, onBack: @escaping () -> Void, backText: String = "‹", right: AnyView? = nil, onRefresh: (() async -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onBack = onBack
        self.backText = backText
        self.right = right
        self.onRefresh = onRefresh
        self.content = content()
        self.bottom = EmptyView()
    }
}

struct ChatBox: View {
    let msgs: [(who: String, text: String, me: Bool)]
    @State private var draft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("留言").font(.caption).foregroundStyle(PT.soft)
            ForEach(Array(msgs.enumerated()), id: \.offset) { _, m in
                Text("\(m.who)：\(m.text)")
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(m.me ? PT.orange.opacity(0.12) : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                TextField("留言…", text: $draft).textFieldStyle(.roundedBorder)
                Button {} label: { Image(systemName: "camera").foregroundStyle(PT.soft) }
                Button {} label: { Text("送出").foregroundStyle(PT.orange).bold() }
            }
        }
        .padding(.top, 14)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let sub: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(PT.soft.opacity(0.6))
                .padding(.bottom, 2)
            Text(title).bold()
            Text(sub).font(.subheadline).foregroundStyle(PT.soft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
