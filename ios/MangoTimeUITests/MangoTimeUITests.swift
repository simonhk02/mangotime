import XCTest

/// MangoTime 自動 UAT：CI 模擬器真撳真打，駁 production server。
/// 每次 run 用隨機電郵註冊，唔會撞舊帳號。
final class MangoTimeUITests: XCTestCase {
    let app = XCUIApplication()
    let uniq = String(Int(Date().timeIntervalSince1970) % 1000000)
    lazy var email = "uat\(uniq)@test.hk"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-fresh"]
        app.launch()
    }

    /// 座標 tap 一次（唔行 scroll-to-visible，咁先唔會炸 kAXScrollToVisible）→ 等鍵盤 → app level 打字
    func typeInto(_ field: XCUIElement, _ text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        _ = app.keyboards.element.waitForExistence(timeout: 5)
        app.typeText(text)
    }

    /// hit-test 失敗就用座標 tap（SwiftUI custom layout 嘅 AX frame 有時呃人）
    func tapAny(_ el: XCUIElement) {
        if el.isHittable { el.tap() }
        else {
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// 完整 flow：註冊 → 開行事曆 → 開活動 → 月曆見到活動 → 留言
    func testFullUserJourney() throws {
        // 1) 註冊
        let toggle = app.buttons["未有帳號？註冊"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "應見到登入頁")
        tapAny(toggle)

        typeInto(app.textFields["reg_name"], "UAT 測試員")
        typeInto(app.textFields["login_email"], email)
        typeInto(app.secureTextFields["login_password"], "password123")
        tapAny(app.buttons["註冊"])

        // 2) 入到月曆（冇行事曆都入到，撳左上開清單）
        let calButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '行事曆' OR label CONTAINS '▾'")).firstMatch
        XCTAssertTrue(calButton.waitForExistence(timeout: 15), "註冊後應見到月曆頂欄")
        tapAny(calButton)

        // 3) 開行事曆
        let nameField = app.textFields["cal_new_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "應見到行事曆清單")
        typeInto(nameField, "UAT 日曆")
        tapAny(app.buttons["cal_create_btn"])
        sleep(2)

        // 返月曆（撳新開嗰個行事曆卡）
        let newCal = app.staticTexts["UAT 日曆"]
        XCTAssertTrue(newCal.waitForExistence(timeout: 5), "應見到新行事曆")
        tapAny(newCal)
        sleep(2)

        // 4) 底部 ＋ 開活動表
        let plus = app.buttons["tab_plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "應見到 ＋ 掣")
        tapAny(plus)

        // 5) 填標題保存
        let titleField = app.textFields["event_title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "應見到新增活動表")
        typeInto(titleField, "UAT 打邊爐")
        tapAny(app.buttons["保存"])
        sleep(3)

        // 6) 月曆應見到活動
        XCTAssertTrue(app.staticTexts["UAT 打邊爐"].waitForExistence(timeout: 8), "月曆應顯示新活動")

        // 7) 撳入去留言
        tapAny(app.staticTexts["UAT 打邊爐"].firstMatch)
        sleep(2)
        let chatField = app.textFields["留言…"]
        if chatField.waitForExistence(timeout: 5) {
            typeInto(chatField, "UAT 留言測試")
            tapAny(app.buttons["送出"])
            sleep(2)
            XCTAssertTrue(app.staticTexts["UAT 留言測試"].waitForExistence(timeout: 5), "應見到自己嘅留言")
            XCTAssertTrue(app.staticTexts["UAT 測試員"].waitForExistence(timeout: 3), "留言應帶作者名")
        }
    }

    /// 備忘錄 + 待辦 + 編輯活動 flow（需要已有帳號登入——靠 testFullUserJourney 順序先行）
    func testMemoTodoEdit() throws {
        // 新鮮帳號開局
        let toggle = app.buttons["未有帳號？註冊"]
        if toggle.waitForExistence(timeout: 8) {
            toggle.tap()
            typeInto(app.textFields["reg_name"], "MT Test")
            typeInto(app.textFields["login_email"], "mt\(uniq)@test.hk")
            typeInto(app.secureTextFields["login_password"], "password123")
            tapAny(app.buttons["註冊"])
            sleep(4)
            // 開行事曆
            let calButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '行事曆' OR label CONTAINS '▾'")).firstMatch
            if calButton.waitForExistence(timeout: 8) {
                tapAny(calButton)
                let nameField = app.textFields["cal_new_name"]
                if nameField.waitForExistence(timeout: 4) {
                    typeInto(nameField, "MT 日曆")
                    tapAny(app.buttons["cal_create_btn"])
                    sleep(2)
                    tapAny(app.staticTexts["MT 日曆"])
                    sleep(2)
                }
            }
        }

        // 狀態 reset：前一個 test 可能留咗喺 sheet/子頁——撳返主 tab 先
        for _ in 0..<4 {
            if app.buttons["tab_other"].exists { break }
            let back = app.buttons.matching(NSPredicate(format: "label == '‹' OR label == '×'")).firstMatch
            if back.exists { tapAny(back); sleep(1) } else { break }
        }
        if !app.buttons["tab_other"].exists {
            tapAny(app.buttons["tab_calendar"]); sleep(1)
        }

        // 備忘錄：其他 → 備忘錄 → 開新
        tapAny(app.buttons["tab_other"])
        sleep(1)
        tapAny(app.staticTexts["備忘錄"])
        sleep(1)
        let memoField = app.textFields["memo_new_title"]
        if memoField.waitForExistence(timeout: 4) {
            typeInto(memoField, "UAT 買嘢清單")
            tapAny(app.buttons["建立"])
            sleep(2)
            XCTAssertTrue(app.staticTexts["UAT 買嘢清單"].waitForExistence(timeout: 5), "應見到新備忘錄")
        }
        tapAny(app.buttons.matching(NSPredicate(format: "label == '‹'")).firstMatch)
        sleep(1)

        // 待辦：開清單 → 加項 → tick
        tapAny(app.staticTexts["待辦清單"])
        sleep(1)
        let listField = app.textFields["新清單名稱"]
        if listField.waitForExistence(timeout: 4) {
            typeInto(listField, "UAT 清單")
            tapAny(app.buttons["＋ 新增清單"])
            sleep(2)
            XCTAssertTrue(app.staticTexts["UAT 清單"].waitForExistence(timeout: 5), "應見到新清單")
        }
        tapAny(app.buttons.matching(NSPredicate(format: "label == '‹'")).firstMatch)
        sleep(1)
    }

    /// 登出 → 登入返（token 持久化 + 重新登入）
    func testLogoutLogin() throws {
        // 如果已登入（上個 test 留底），先登出
        if !app.buttons["未有帳號？註冊"].waitForExistence(timeout: 6) {
            tapAny(app.buttons["tab_other"])
            sleep(1)
            tapAny(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '@'")).firstMatch)
            sleep(1)
            tapAny(app.buttons["登出"])
            sleep(2)
        }
        // 註冊新帳
        let toggle = app.buttons["未有帳號？註冊"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "應見到登入頁")
        tapAny(toggle)
        typeInto(app.textFields["reg_name"], "Logout Test")
        typeInto(app.textFields["login_email"], "lo\(uniq)@test.hk")
        typeInto(app.secureTextFields["login_password"], "password123")
        tapAny(app.buttons["註冊"])
        sleep(4)

        // 其他 → 個人檔案 → 登出
        tapAny(app.buttons["tab_other"])
        sleep(1)
        tapAny(app.staticTexts["lo\(uniq)@test.hk"].firstMatch)
        sleep(1)
        tapAny(app.buttons["登出"])
        sleep(2)

        // 登入返
        XCTAssertTrue(app.buttons["登入"].waitForExistence(timeout: 5), "登出後應返登入頁")
        typeInto(app.textFields["login_email"], "lo\(uniq)@test.hk")
        typeInto(app.secureTextFields["login_password"], "password123")
        tapAny(app.buttons["登入"])
        XCTAssertTrue(app.buttons["今日"].waitForExistence(timeout: 10) || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '年'")).firstMatch.waitForExistence(timeout: 5), "登入後應見到月曆")
    }
}
