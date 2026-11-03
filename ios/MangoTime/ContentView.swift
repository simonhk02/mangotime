import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var api: APIClient
    @State private var serverStatus = "Checking server…"

    var body: some View {
        VStack(spacing: 16) {
            Text("MangoTime")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let user = api.currentUser {
                Text("你好，\(user.displayName)")
                    .font(.title3)
            }

            Text(serverStatus)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            CalendarListView()

            Button("登出（\(api.currentUser?.email ?? "")）") {
                Task { await api.logout() }
            }
            .font(.footnote)
        }
        .padding()
        .onAppear {
            Task {
                await checkHealth()
            }
        }
    }

    private func checkHealth() async {
        guard let url = URL(string: "\(api.baseURL)/health") else {
            serverStatus = "Invalid server URL"
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            serverStatus = "Server OK (HTTP \(code)): \(body)"
        } catch {
            serverStatus = "Server unreachable: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView().environmentObject(APIClient.shared)
}
