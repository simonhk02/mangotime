import SwiftUI

@main
struct MangoTimeApp: App {
    @StateObject private var api = APIClient.shared

    var body: some Scene {
        WindowGroup {
            // 預設：LIVE 模式（駁真 server）；`-proto` = 純 mock 原型（cap 圖用）
            if ProcessInfo.processInfo.arguments.contains("-proto") {
                ProtoRootView(live: false)
            } else {
                ProtoRootView(live: true)
            }
        }
    }
}
