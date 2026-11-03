import SwiftUI

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
    let label: String
    var value: String = ""
    var valueColor: Color = PT.soft
    var toggle: Binding<Bool>? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        Button {
            if let t = toggle { t.wrappedValue.toggle() } else { action?() }
        } label: {
            HStack {
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

struct PSheet<Content: View>: View {
    let title: String
    var onBack: () -> Void
    var backText: String = "‹"
    var right: AnyView? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            PNavBar(title, left: {
                Button(action: onBack) { Text(backText).font(.title3).foregroundStyle(PT.orange) }
            }, right: { right })
            ScrollView { VStack(spacing: 0) { content }.padding(.horizontal, 16) }
        }
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
                Button {} label: { Text("📷") }
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
            Text(icon).font(.system(size: 44))
            Text(title).bold()
            Text(sub).font(.subheadline).foregroundStyle(PT.soft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
