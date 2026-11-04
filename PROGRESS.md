# 進度表 — MangoTime 項目

> 更新規則：每完成一個步驟，我（PM）會更新狀態＋喺 Telegram 報告俾 Simon review。
> 狀態：⬜ 未開始 ｜ 🟦 進行中 ｜ 🟨 待驗收 ｜ ✅ 完成
> 已定方向（2026-11-02 Simon 拍板）：平台 **Web + iOS 並行**；進度表＝**VPS dashboard**＋每步 Telegram 報告
> 📊 Dashboard：http://mangotime-dash.149-28-154-219.sslip.io/p/8405d1cf18b84f1a84951d98a1ab99ea/ （暫用 HTTP＋token path；加咗 DNS record 會轉 HTTPS）

| ID | 功能 | 狀態 | 驗收記錄 | 完成日期 |
|----|------|------|----------|----------|
| 0.1 | Feature inventory（spec 基底） | ✅ 完成 | Simon approve 2026-11-02 | 2026-11-02 |
| 0.2 | 架構定案（docs/ARCHITECTURE.md） | ✅ 完成 | Simon approve 2026-11-02；多用戶同步原則已補入 | 2026-11-02 |
| 0.3 | 項目骨架＋CI＋VPS 進度 dashboard | ✅ 完成 | CI green；iOS build 1 已上 TestFlight（2026-11-03，state VALID） | 2026-11-03 |
| 1.1 | Auth＋profile | 🟨 待驗收 | email 註冊/登入/登出/profile API 8/8 tests pass；Web 登入註冊頁（build green）；iOS 登入頁（CLT typecheck 0 errors）。Google/Apple 登入留返 Phase 1 尾（要開 OAuth app） | |
| 1.2 | Calendar CRUD | 🟨 待驗收 | 開/改/刪/列出日曆 API（membership-scoped，非成員 404 唔洩存在）；每個改動寫 OutboxEvent（webhook 4.2 用）；16/16 tests；Web 日曆清單頁 + iOS CalendarListView（CLT 0 errors）；MCP list_calendars/create_calendar 經 stdio 實測開咗個日曆出嚟 | |
| 1.3 | Members & invite | 🟨 待驗收 | Invite link API（開/預覽/接受/成員列表/creator移除）8 tests 全過（32/32）；production 實測開碼 OK；iOS live：邀請碼複製、成員列表、用邀請碼加入 | |
| 1.4 | Event CRUD | 🟨 待驗收 | 全欄位 API（repeat/label/note/url/location/remind）、範圍查詢、權限；24/24 tests；outbox event.* | |
| 1.5 | Month view＋calendar overlay | 🟨 待驗收 | TimeTree 1:1 版面（頂欄/行事曆清單/右直欄）；**農曆雙行日期**（對到參考圖）；雙擊開活動表；獨睇/toggle overlay | |
| 2.1 | Event comments（chat＋貼相） | 🟨 待驗收 | 留言 API（列出/留言/刪除自己，outbox event.comment_created）35/35 tests；production 已部署；iOS 活動詳情真留言。貼相留待 2.4 相簿一齊做 | |
| 2.2 | Memo | 🟨 待驗收 | CRUD+留言 API（38/38 tests，commentCount，outbox memo.*）；production 已部署；iOS 備忘錄列表/開新/詳情/留言/刪除全變真 | |
| 2.3 | To-Do List | 🟨 待驗收 | List CRUD + item 加/toggle(doneBy)/刪，done/total 計數，outbox todo.*；42/42 tests；production 已部署；iOS 全變真（開清單/加項/tick/刪） | |
| 2.4 | Album | ⬜ | | |
| 2.5 | Activity＋Notices | ⬜ | | |
| 2.6 | Notifications | ⬜ | | |
| 3.1 | Weekly／直向 view | ⬜ | | |
| 3.2 | Search | ⬜ | | |
| 3.3 | Dark mode | ⬜ | | |
| 3.4 | 農曆顯示 | ⬜ | | |
| 4.1 | Public REST API | ⬜ | | |
| 4.2 | Webhook | ⬜ | | |
| 4.3 | MCP server | ⬜ | | |
| 5.1 | External calendar sync | ⬜ | | |
| 5.2 | Public Calendar＋embed widget | ⬜ | | |
| 5.3 | Event Scan（AI 抽日期） | ⬜ | | |
| 5.4 | 檔案附件 | ⬜ | | |
| 5.5 | iCal import/export | ⬜ | | |
