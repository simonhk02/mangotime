import SwiftUI

@main
struct MangoTimeApp: App {
    @StateObject private var api = APIClient.shared

    var body: some Scene {
        WindowGroup {
            // 現階段：預設行原型（TestFlight 驗畫面）；真 app 流程留喺 -real 後面
            if ProcessInfo.processInfo.arguments.contains("-real") {
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
            } else {
                ProtoRootView()
            }
        }
    }
}
