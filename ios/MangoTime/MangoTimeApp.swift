import SwiftUI

@main
struct MangoTimeApp: App {
    @StateObject private var api = APIClient.shared

    var body: some Scene {
        WindowGroup {
            // 原型模式：launch argument `-proto` 開啟 → 全 mock 畫面（對照 TimeTree 參考圖）
            if ProcessInfo.processInfo.arguments.contains("-proto") {
                ProtoRootView()
            } else {
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
}
