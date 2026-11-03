import SwiftUI

struct ContentView: View {
    @State private var serverStatus = "Checking server…"

    var body: some View {
        VStack(spacing: 16) {
            Text("MangoTime")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(serverStatus)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .onAppear {
            Task {
                await checkHealth()
            }
        }
    }

    private func checkHealth() async {
        // Mac mini on the home LAN (server/ runs on port 8787).
        // localhost on a physical device would point at the device itself.
        guard let url = URL(string: "http://192.168.0.145:8787/health") else {
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
    ContentView()
}
