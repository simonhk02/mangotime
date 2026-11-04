import XCTest

/// MangoTime 自動 UAT：CI 模擬器真撳真打，駁 production server。
/// 每次 run 用隨機電郵註冊，唔會撞舊帳號。
final class MangoTimeUITests: XCTestCase {
    let app = XCUIApplication()
    let uniq = String(Int(Date().timeIntervalSince1970) % 1000000)
    lazy var email = "uat\(uniq)@test.hk"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// tap 完等鍵盤出先打字；第一次 tap 唔中 focus 就再 tap
    func typeInto(_ field: XCUIElement, _ text: String) {
        field.tap()
        if !app.keyboards.element.waitForExistence(timeout: 3) {
            field.tap()
            _ = app.keyboards.element.waitForExistence(timeout: 3)
        }
        field.typeText(text)
    }

    /// 完整 flow：註冊 → 開行事曆 → 開活動 → 月曆見到活動 → 留言
    func testFullUserJourney() throws {
        // 1) 註冊
        let toggle = app.buttons["未有帳號？註冊"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "應見到登入頁")
        toggle.tap()

        typeInto(app.textFields["reg_name"], "UAT 測試員")
        typeInto(app.textFields["login_email"], email)
        typeInto(app.secureTextFields["login_password"], "password123")
        app.buttons["註冊"].tap()

        // 2) 入到月曆（冇行事曆都入到，撳左上開清單）
        let calButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '行事曆' OR label CONTAINS '▾'")).firstMatch
        XCTAssertTrue(calButton.waitForExistence(timeout: 15), "註冊後應見到月曆頂欄")
        calButton.tap()

        // 3) 開行事曆
        let nameField = app.textFields["cal_new_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "應見到行事曆清單")
        typeInto(nameField, "UAT 日曆")
        app.buttons["cal_create_btn"].tap()
        sleep(2)

        // 返月曆（撳新開嗰個行事曆卡）
        let newCal = app.staticTexts["UAT 日曆"]
        XCTAssertTrue(newCal.waitForExistence(timeout: 5), "應見到新行事曆")
        newCal.tap()
        sleep(2)

        // 4) 底部 ＋ 開活動表
        let plus = app.buttons["tab_plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "應見到 ＋ 掣")
        plus.tap()

        // 5) 填標題保存
        let titleField = app.textFields["event_title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "應見到新增活動表")
        typeInto(titleField, "UAT 打邊爐")
        app.buttons["保存"].tap()
        sleep(3)

        // 6) 月曆應見到活動
        XCTAssertTrue(app.staticTexts["UAT 打邊爐"].waitForExistence(timeout: 8), "月曆應顯示新活動")

        // 7) 撳入去留言
        app.staticTexts["UAT 打邊爐"].firstMatch.tap()
        sleep(2)
        let chatField = app.textFields["留言…"]
        if chatField.waitForExistence(timeout: 5) {
            typeInto(chatField, "UAT 留言測試")
            app.buttons["送出"].tap()
            sleep(2)
            XCTAssertTrue(app.staticTexts["UAT 留言測試"].waitForExistence(timeout: 5), "應見到自己嘅留言")
            XCTAssertTrue(app.staticTexts["UAT 測試員"].waitForExistence(timeout: 3), "留言應帶作者名")
        }
    }

    /// 登出 → 登入返（token 持久化 + 重新登入）
    func testLogoutLogin() throws {
        // 如果已登入（上個 test 留底），先登出
        if !app.buttons["未有帳號？註冊"].waitForExistence(timeout: 6) {
            app.buttons["tab_other"].tap()
            sleep(1)
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '@'")).firstMatch.tap()
            sleep(1)
            app.buttons["登出"].tap()
            sleep(2)
        }
        // 註冊新帳
        let toggle = app.buttons["未有帳號？註冊"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "應見到登入頁")
        toggle.tap()
        typeInto(app.textFields["reg_name"], "Logout Test")
        typeInto(app.textFields["login_email"], "lo\(uniq)@test.hk")
        typeInto(app.secureTextFields["login_password"], "password123")
        app.buttons["註冊"].tap()
        sleep(4)

        // 其他 → 個人檔案 → 登出
        app.buttons["tab_other"].tap()
        sleep(1)
        app.staticTexts["lo\(uniq)@test.hk"].firstMatch.tap()
        sleep(1)
        app.buttons["登出"].tap()
        sleep(2)

        // 登入返
        XCTAssertTrue(app.buttons["登入"].waitForExistence(timeout: 5), "登出後應返登入頁")
        typeInto(app.textFields["login_email"], "lo\(uniq)@test.hk")
        typeInto(app.secureTextFields["login_password"], "password123")
        app.buttons["登入"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '▾'")).firstMatch.waitForExistence(timeout: 10), "登入後應見到月曆")
    }
}
