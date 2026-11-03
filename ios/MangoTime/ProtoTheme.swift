import SwiftUI

/// 原型主題色（對照 TimeTree）
enum PT {
    static let orange = Color(red: 1.0, green: 0.44, blue: 0.26)   // #FF7043
    static let green = Color(red: 0.06, green: 0.73, blue: 0.51)   // #10B981
    static let blue = Color(red: 0.23, green: 0.51, blue: 0.96)    // #3B82F6
    static let red = Color(red: 0.94, green: 0.27, blue: 0.27)     // #EF4444
    static let purple = Color(red: 0.66, green: 0.33, blue: 0.97)  // #A855F7
    static let soft = Color(red: 0.54, green: 0.58, blue: 0.63)    // #8A94A1
    static let bg = Color(red: 0.97, green: 0.97, blue: 0.98)      // #F7F8FA
}

struct MockEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let day: Int
    let color: Color
    let loc: String
    let time: String
    var attach: Int = 0
}

struct MockMemo: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let color: Color
}

struct MockTodo: Identifiable {
    let id: String
    let text: String
    var done: Bool
}

struct MockMember: Identifiable {
    let id: String
    let name: String
    let role: String
    let color: Color
}

struct HelpCat: Identifiable, Hashable {
    let id: String
    let icon: String
    let name: String
    let arts: [String]
}

enum Mock {
    static let events: [MockEvent] = [
        .init(id: "1", title: "屋企人飯局", day: 18, color: PT.green, loc: "酒樓", time: "19:00–22:00"),
        .init(id: "2", title: "珠海兩日一夜", day: 18, color: PT.blue, loc: "珠海", time: "全日", attach: 2),
        .init(id: "3", title: "打邊爐", day: 19, color: PT.red, loc: "屋企", time: "19:30–23:00"),
        .init(id: "4", title: "網球", day: 20, color: PT.orange, loc: "", time: "08:00–10:00"),
        .init(id: "5", title: "阿女家長日", day: 24, color: PT.purple, loc: "學校", time: "14:00–16:00"),
    ]
    static let memos: [MockMemo] = [
        .init(id: "m1", title: "買嘢清單", body: "紙巾、洗衣液、貓糧", color: PT.orange),
        .init(id: "m2", title: "想食嘅餐廳", body: "沙田新開嗰間拉麵", color: PT.blue),
    ]
    static let todos: [MockTodo] = [
        .init(id: "t1", text: "訂酒樓", done: true),
        .init(id: "t2", text: "問埋舅父得唔得閒", done: false),
    ]
    static let members: [MockMember] = [
        .init(id: "u1", name: "阿文（我）", role: "建立者", color: PT.orange),
        .init(id: "u2", name: "老婆", role: "成員", color: PT.green),
        .init(id: "u3", name: "阿女", role: "成員", color: PT.blue),
    ]
    static let photos = ["🍲","🏖","🎾","🎂","🐱","🌊","🍜","🎁","🏸"]
    static let labels: [(String, Color)] = [
        ("Bright Orange", PT.orange), ("Emerald Green", PT.green),
        ("Blue", PT.blue), ("Red", PT.red), ("Purple", PT.purple),
    ]
    static let helpCats: [HelpCat] = [
        .init(id: "c1", icon: "🌱", name: "給初次使用者", arts: ["想知道共享日曆的各功能（應用程序版）","行程未被共享","希望定期收到通知"]),
        .init(id: "c2", icon: "👤", name: "帳戶管理", arts: ["想要註冊帳號","因變更機型而希望繼承數據","登入帳戶並使用現有資料","想要從所有裝置登出","我要刪除帳號／退出服務"]),
        .init(id: "c3", icon: "📝", name: "創建/編輯事件", arts: ["想從圖片建立行程（掃描圖片）","複製/刪除/編輯計劃","輕鬆登錄行程","每週〇曜日的行程登錄方法（重複設定）"]),
        .init(id: "c4", icon: "📅", name: "關於日曆", arts: ["希望以時間單位顯示預定（垂直顯示）","希望減少通知頻率（每天一次彙總通知）","我想更改顏色"]),
        .init(id: "c5", icon: "⚙️", name: "各種應用程序設置", arts: ["通知不到","我想更改語言","想了解通知的種類與頻率","希望自動輸入標題"]),
        .init(id: "c6", icon: "🛠", name: "實際使用", arts: ["想要新增或刪除相簿中的照片","搜尋行程","我要登錄或查看備忘錄"]),
        .init(id: "c7", icon: "🔗", name: "將TimeTree與其他日曆一起使用", arts: ["想使用其他日曆（例如 Google 日曆）"]),
        .init(id: "c8", icon: "🩹", name: "解決問題", arts: ["小工具未顯示行程","顯示錯誤","行事消失","無法查看"]),
        .init(id: "c9", icon: "💬", name: "其他話題", arts: ["關於聯絡客服的方法","關於支援版本（OS/應用程式）"]),
        .init(id: "c10", icon: "🌍", name: "關於公開行事曆［管理員］", arts: ["［管理者］取得公開行事曆中活動的二維碼並刊載於印刷品"]),
    ]
    static let articleBody: [String: [String]] = [
        "小工具未顯示行程": ["請確認以下內容","iOS / Android：確認行事曆已開啟同步","確認小工具揀咗正確行事曆","重新開機後再試"],
        "因變更機型而希望繼承數據": ["為您介紹更換智能手機機型所需的步驟。","1. 舊機：確認已註冊帳號並登入","2. 新機：安裝 MangoTime 並登入同一帳號","3. 資料會自動同步"],
        "登入帳戶並使用現有資料": ["iOS / Android：喺登入頁輸入已註冊嘅電郵同密碼，即可沿用現有行事曆資料。"],
        "每週〇曜日的行程登錄方法（重複設定）": ["新增活動 →「重複」→ 揀「每週」→ 揀星期幾。可以隨時單次修改或整個系列修改。"],
        "想使用其他日曆（例如 Google 日曆）": ["設定 →「外部日曆」→ 連結 Google 帳戶。Google 日曆嘅行程會以唯讀方式顯示。"],
        "行程未被共享": ["1. 行程登錄者登錄在「其他行事曆」上","解決方法：請對方確認行程所屬行事曆，並確認你已加入該行事曆。"],
        "我要刪除帳號／退出服務": ["帳號刪除、退出操作後將無法復原。退出操作後的資料將被完全刪除。"],
        "搜尋行程": ["在『主行事曆』中，您加入的所有共享行事曆都將納入搜尋範圍。指定參加者或標籤可篩選。"],
        "我要登錄或查看備忘錄": ["可作為簡單備忘錄、購物清單、想去的地方清單、待辦事項等使用。每條備忘錄都可以留言。"],
        "想要新增或刪除相簿中的照片": ["相簿 → ＋上傳；長按照片可刪除。上傳檔案屬 Premium 功能。"],
    ]
}
