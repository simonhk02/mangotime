# Feature Inventory — MangoTime（TimeTree-referenced rebuild）

> 目的：復刻 TimeTree 嘅**功能行為**（UI/品牌自家設計），並內建 TimeTree 冇嘅 **API + Webhook + MCP**。
> 參考基準：Simon 嘅 TimeTree 帳號實機 walkthrough（2026-11-02，Safari web 版）＋ `docs/ref-caps/` 截圖 ＋ TimeTree Help Center ＋ Simon 嘅手機 cap 圖（Google Drive）。
> 狀態：v0.2 待 Simon approve（2026-11-02 更新：平台拍板 **Web + iOS 雙 client 並行**）

## 架構原則（好重要）

- **API-first**：所有功能先做 REST API；Web app 同 iOS app 都係 API 嘅 client，兩個一齊做。
- 每個功能 task 嘅交付物 = **API endpoint + Web UI + MCP tool + webhook event**，一齊過，唔准留尾。
- 咁樣 MCP/webhook 唔係事後加裝，而係由第一個功能開始就係產品嘅一部分。

## 已實機確認嘅 TimeTree 結構（web 版）

- 主畫面：月曆格（有農曆日期顯示）、Today/上個月/下個月、Monthly/Weekly 切換、搜尋、Create event、Settings
- 左側欄：Calendar List（每個 calendar 卡有封面圖、名、成員頭像、「Show only this calendar」獨睇掣）、Add Calendar
- 撳 calendar 名 = toggle 顯示/隱藏（filter overlay）
- 右側直 bar：Memo / Album / Member List / Activity / Notices / Calendar Settings
- Create Event 表單：Event/Memo 雙 tab、title（必填）、All-day、Starts/Ends、Repeat、Remind、Members（指派）、Label（顏色，如 Emerald green）、Note、To-Do List、地點、URL、Files（Premium 限定）
- Create Memo 表單：同上但無日期（未定日期嘅事項）
- Member List：Add（邀請）、搜尋成員、「Your Events」按成員過濾、角色（Creator）
- Calendar Settings：Calendar details（改名、封面圖）、Display Settings
- Web 版已有 dark mode

---

## 功能分拆（每行 = 一個 agent task，逐個做）

### Phase 0 — 地基
- **0.1** Feature inventory 本文件 ✅（待 Simon approve）
- **0.2** 架構定案：平台（Web + iOS）、stack、DB schema v1、repo 結構 → 見 `docs/ARCHITECTURE.md`
- **0.3** 項目骨架：server + web shell + iOS shell + DB + 本地 run 脚本 + CI build check + VPS 進度 dashboard

### Phase 1 — 核心
- **1.1 Auth**：email 註冊/登入 + Google 登入；user profile（顯示名、頭像）
- **1.2 Calendar CRUD**：開/改名/封面圖/刪除 calendar
- **1.3 Members & invite**：邀請 link、join flow、Member List、角色（creator/member）、remove member
- **1.4 Event CRUD**：title、all-day、start/end、repeat（唔重複/每日/每周/每月/每年）、remind、指派 members、label 顏色、note、URL、地點
- **1.5 Month view**：月曆格、event 顯示（label 色）、多 calendar overlay/toggle、獨睇某一個、Today/切月

### Phase 2 — 協作
- **2.1 Event comments**：event 內 chat、留言可貼相
- **2.2 Memo**：無日期事項（title/members/label/note/URL/地點）
- **2.3 To-Do List**：event/memo 內 checklist
- **2.4 Album**：每個 calendar 嘅共享相簿
- **2.5 Activity feed + Notices**：邊個改咗咩、公告
- **2.6 Notifications**：event 提醒、更新通知（web push / email）

### Phase 3 — 睇法同體驗
- **3.1 Weekly view**＋直向日曆 view
- **3.2 Search**：關鍵字搜 event/memo
- **3.3 Dark mode**
- **3.4 農曆日期顯示**（香港用戶啱用）

### Phase 4 — 差異化（Simon 指定優先）
- **4.1 Public REST API**：token auth、CRUD 全開、rate limit、API docs 頁
- **4.2 Webhook**：event/memo/member 變更即時 POST 出去（可篩 event 類型、retry、簽名）
- **4.3 MCP server**：agent 可以經 MCP 讀寫 calendar/event/memo/to-do（tools: list_calendars, list_events, create_event, update_event, create_memo, …）

### Phase 5 — 延伸
- **5.1 External calendar sync**：顯示/copy Google Calendar 等（TimeTree 係單向顯示＋手動 copy）
- **5.2 Public Calendar**：公開發佈、follow/unfollow、like/save event、copy 去自己 calendar、嵌入網站 widget
- **5.3 Event Scan**：影相/截圖 → AI 抽出日期建立 event
- **5.4 檔案附件**（PDF 等）
- **5.5 iCal import/export**

## 每個 task 嘅驗收標準（template）

1. API 回應同 TimeTree 行為對齊（以實機/cap 圖為準）
2. Web UI 做到一樣操作流
3. MCP tool 可以完成同一操作
4. 相應 webhook 有 fire
5. 我自己親手 run 過一次 end-to-end 先剔完成
