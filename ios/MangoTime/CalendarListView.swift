import SwiftUI

struct CalendarListView: View {
    @EnvironmentObject private var api: APIClient
    @State private var calendars: [MTCalendar] = []
    @State private var newName = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("新日曆名稱…", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("建立") {
                    Task { await create() }
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }

            if calendars.isEmpty {
                Text("仲未有日曆，開一個啦。")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(calendars) { cal in
                        VStack(alignment: .leading) {
                            Text(cal.name).fontWeight(.medium)
                            Text("\(cal.memberCount ?? 1) 位成員\(cal.myRole == "creator" ? " · 我係建立者" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 200)
            }
        }
        .padding()
        .task { await refresh() }
    }

    private func refresh() async {
        do {
            calendars = try await api.listCalendars()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func create() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            _ = try await api.createCalendar(name: name)
            newName = ""
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    CalendarListView().environmentObject(APIClient.shared)
}
