# TASK 0.3 — 項目骨架（server + web + iOS + mcp + CI）＋ VPS 進度 dashboard

> 狀態：🟦 進行中（2026-11-02 開）
> 派工：subagent A（server/web/mcp/CI）、subagent B（iOS shell）；VPS dashboard 由 PM 親自做
> 驗收：PM 親手 run 下面「驗收清單」每項先剔 ✅

## 範圍

Monorepo `/Users/simon/shared-cal/`（`docs/`、`PROGRESS.md` 已存在，**唔准掂**）。

### A. server/（TypeScript）
- Fastify + Prisma + SQLite（WAL），DB 檔 `server/data/mangotime.db`
- Prisma schema v0：**User** 得四個欄位（id, email, displayName, avatarUrl, createdAt）——真正 auth 係 task 1.1
- Endpoints：`GET /health` → `{ ok: true, version }`；`GET /v1/ping` → `{ pong: true }`
- OpenAPI：`openapi.yaml` 手寫 v0 骨架＋ serve 喺 `/docs`
- scripts：`dev`（watch）、`build`、`start`；`.env.example`（PORT=8787）
- `npx prisma migrate dev` 真係行到

### B. web/（React + Vite + TS）
- 單頁 shell：顯示「MangoTime」＋ call `GET /api/health`（vite proxy → `localhost:8787`）顯示結果
- `npm run build` 過到

### C. mcp/（TypeScript）
- `@modelcontextprotocol/sdk`，stdio transport
- 一個 tool：`ping`（打去 server `/health` 返結果）
- smoke test 證明 stdio 起到、tool call 有回應

### D. 根目錄
- `README.md` quickstart（點樣起 server/web/mcp）
- `.gitignore`（node_modules、dist、data/、.env）
- `git init`＋ initial commit（local，唔好 push）
- `.github/workflows/ci.yml`：server＋web typecheck/build（file 齊就得，未 push 唔緊要）

### E. ios/（SwiftUI shell）
- App 名 **MangoTime**，iOS 17+，Swift 5 mode（Simon 慣例），bundle id `com.mangotime.app`
- 單屏：「MangoTime」標題＋開 app 時 call `http://localhost:8787/health` 顯示 server 狀態（記得 ATS 嘅 localhost 例外）
- 項目生成方法任揀（XcodeGen binary 或手寫 pbxproj），但**必須**喺本機 Xcode 26.3 用 `xcodebuild` 真係 build 到 simulator target

## 驗收清單（PM 親自逐項跑）

1. `node -v`/`npm -v` 存在（冇就用 GitHub binary 裝，冇 brew）
2. server：`npm run build` 過、`curl localhost:8787/health` 有回應、prisma migrate 行到
3. web：`npm run build` 過、dev server 開到、頁面真係顯示到 health 結果
4. mcp：stdio smoke test 過
5. ios：`xcodebuild` build 成功
6. git log 有 initial commit
7. VPS dashboard：URL 由外網（手機）開到，內容＝PROGRESS.md 渲染

## 規矩

- 唔准掂 `docs/`（除咗讀）同 `PROGRESS.md`
- 唔准 sudo、唔准裝系統級嘢、唔准 push 去任何 remote
- 每個 subagent 交報告要附**真實指令＋輸出**，唔係淨係講「done」
