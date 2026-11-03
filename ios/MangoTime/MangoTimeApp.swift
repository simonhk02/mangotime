import SwiftUI

@main
struct MangoTimeApp: App {
    @StateObject private var api = APIClient.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if api.token != nil {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .environmentObject(api)
            .task {
                if api.token != nil {
                    try? await api.fetchMe()
                }
            }
        }
    }
}
