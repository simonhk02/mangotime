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
| 1.1 | Auth＋profile | 🟨 待驗收 | email 註冊/登入/登出/profile API 8/8 tests pass；Web 登入註冊頁（build green）；iOS 登入頁。**Social auth**：jose JWKS 驗簽（Apple/Google idToken）+ SocialAccount model（email 對到自動併帳，60/60 tests）；ASC 已開 Sign in with Apple capability；iOS 真 SignInWithAppleButton。Google 掣等 Google Cloud OAuth client | |
| 1.2 | Calendar CRUD | 🟨 待驗收 | 開/改/刪/列出日曆 API（membership-scoped，非成員 404 唔洩存在）；每個改動寫 OutboxEvent（webhook 4.2 用）；16/16 tests；Web 日曆清單頁 + iOS CalendarListView（CLT 0 errors）；MCP list_calendars/create_calendar 經 stdio 實測開咗個日曆出嚟 | |
| 1.3 | Members & invite | 🟨 待驗收 | Invite link API（開/預覽/接受/成員列表/creator移除）8 tests 全過（32/32）；production 實測開碼 OK；iOS live：邀請碼複製、成員列表、用邀請碼加入 | |
| 1.4 | Event CRUD | 🟨 待驗收 | 全欄位 API（repeat/label/note/url/location/remind）、範圍查詢、權限；24/24 tests；outbox event.* | |
| 1.5 | Month view＋calendar overlay | 🟨 待驗收 | TimeTree 1:1 版面（頂欄/行事曆清單/右直欄）；**農曆雙行日期**（對到參考圖）；雙擊開活動表；獨睇/toggle overlay | |
| 2.1 | Event comments（chat＋貼相） | 🟨 待驗收 | 留言 API（列出/留言/刪除自己，outbox event.comment_created）35/35 tests；production 已部署；iOS 活動詳情真留言。貼相留待 2.4 相簿一齊做 | |
| 2.2 | Memo | 🟨 待驗收 | CRUD+留言 API（38/38 tests，commentCount，outbox memo.*）；production 已部署；iOS 備忘錄列表/開新/詳情/留言/刪除全變真 | |
| 2.3 | To-Do List | 🟨 待驗收 | List CRUD + item 加/toggle(doneBy)/刪，done/total 計數，outbox todo.*；42/42 tests；production 已部署；iOS 全變真（開清單/加項/tick/刪） | |
| 2.4 | Album | 🟨 待驗收 | base64 上傳（8MB 上限、jpg/png/webp/heic）→ VPS /data/uploads → cuid 公開 URL（cache 1 年）；44/44 tests；production 實測上傳+攞相 OK；nginx body 20m；iOS PhotosUI 揀相壓縮上傳、AsyncImage grid、長按刪自己相 | |
| 2.5 | Activity＋Notices | 🟨 待驗收 | /activity 直讀 outbox（全部 18 種動作→廣東話 summary+icon，actor join，46/46 tests）；production 實測 feed OK；iOS 行程 tab 真 feed（相對時間）+ 相簿 tab 真相。Notices（2.6）分開做 | |
| 2.6 | Notifications | 🟨 待驗收 | /notices：其他成員喺我行事曆嘅動作（自己嘅唔計，48/48 tests）；production 已部署；iOS 通知頁變真+下拉更新。APNs 推送留返上架前 | |
| 3.1 | Weekly／直向 view | 🟨 待驗收 | 直向時間軸：00–23 鐘格線、定時活動按鐘擺位（高度=時長）、全日分開處理、撳入詳情；mock/live 兩用 | |
| 3.2 | Search | 🟨 待驗收 | /events/search?q=（title/location/note contains，53/53 tests）；iOS 搜尋頁即打即搜變真 | |
| 3.3 | Dark mode | ✅ 完成 | 全 app 用 system colors（systemBackground/separator/label），無 hardcoded 白底——iOS dark mode 自動跟 | 2026-11-04 |
| 3.4 | 農曆顯示 | ✅ 完成 | 月曆格新曆+農曆雙行（查表法 1900–2100，對到參考圖 11/15=十月初七）；顯示設定有開關，Lunar.swift 同 web lunar.ts 對齊 | 2026-11-04 |
| 4.1 | Public REST API | 🟨 待驗收 | `/v1/*` 全部公開 HTTPS；API key（`mt_` 開頭，只存 hash，lastUsedAt）開/列/廢除；auth 同時接 session token + API key；production 實測 key 打 API OK | |
| 4.2 | Webhook | 🟨 待驗收 | 訂閱 API（https 強制，localhost 例外）+ dispatcher 每 10s 掃 outbox 派遞，HMAC-SHA256 簽名（x-mangotime-signature），51/51 tests 包真 receiver 收料+驗簽 | |
| 4.3 | MCP server | 🟨 待驗收 | 21 個 tools（events/memos/todos/comments/invites/activity/notices/webhooks 全套）；stdio smoke E2E 打 production 全過（list→create→activity→delete） | |
| 5.1 | External calendar sync | ⬜ | | |
| 5.2 | Public Calendar＋embed widget | 🟨 待驗收 | publicSlug 開/關 API + /v1/public/:slug（sanitize 唔洩 creatorId，55/55 tests）；web 唯讀月曆頁上咗 https://mangotime.149-28-154-219.sslip.io/public/<slug>（Chrome headless 實測渲染 OK）；iOS 邀請頁一撳開＋複製；embed widget 留返下一步 | |
| 5.3 | Event Scan（AI 抽日期） | ⬜ | | |
| 5.4 | 檔案附件 | 🟨 待驗收 | Attachment model + base64 上傳/攞檔/刪除（57/57 tests，VPS live）；iOS 詳情頁 📎 附件區：PhotosPicker 加相 + 縮圖橫列；PDF 都收 | |
| 5.5 | iCal import/export | ⬜ | | |
