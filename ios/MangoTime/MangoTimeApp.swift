import SwiftUI
import UserNotifications

/// APNs：攞 device token → 上俾 server（登入咗先有意思）
final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { try? await APIClient.shared.registerDevice(token: token) }
    }

    // 前景都照顯示橫額（唔係靜靜雞食咗佢）
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

@main
struct MangoTimeApp: App {
    @StateObject private var api = APIClient.shared
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var pushDelegate

    var body: some Scene {
        WindowGroup {
            // 預設：LIVE 模式（駁真 server）；`-proto` = 純 mock 原型（cap 圖用）
            if ProcessInfo.processInfo.arguments.contains("-proto") {
                ProtoRootView(live: false)
            } else {
                ProtoRootView(live: true)
                    .onAppear { requestPushPermission() }
            }
        }
    }

    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
