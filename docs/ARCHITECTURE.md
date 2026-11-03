# Architecture — MangoTime

> v0.1（2026-11-02）｜已定方向：**Web + iOS 並行**；進度表＝**VPS dashboard**＋每步 Telegram 報告

## 總覽

```
[iOS app SwiftUI] ┐
[Web app React]   ├─ HTTPS/JSON ─> [API server] ─> [SQLite]
[Agents via MCP] ─┘                    │
                                       ├─> [Webhook dispatcher]（outbox＋worker）
                                       └─> [MCP server]（共用 service layer，唔直接掂 DB）
```

## Monorepo：`/Users/simon/shared-cal/`

- `server/` — API server：**TypeScript + Fastify + Prisma**（SQLite WAL）。推薦 TS：全棧同一語言，MCP 官方 SDK 係 TS first-class
- `web/` — React + Vite
- `ios/` — SwiftUI，iOS 17+；本機 Xcode 26.3 已確認；之後 TestFlight（Simon 有付費 Developer 帳號）
- `mcp/` — MCP server（stdio＋HTTP transport）
- `docs/` — spec、ref-caps、本文件

## 關鍵決定

- **API-first**：Web／iOS／MCP 全部行同一套 REST API；OpenAPI spec 係三方合約
- **DB**：SQLite（WAL）起步——單檔、易備份、同你 VPS 其他產品一致；真係爆量先 migrate Postgres
- **Auth**：email＋密碼（session token）、Sign in with Apple（iOS 上架硬性要求）、Google（web）
- **Webhook**：outbox table＋背景 worker（durable queue，你熟嘅 pattern）；HMAC-SHA256 簽名、exponential backoff retry、死信記錄
- **Sync**：v1 REST＋client poll；v2 先加 WebSocket/SSE
- **Hosting**：dev 喺呢部 Mac mini；prod 上你 Vultr VPS（nginx reverse proxy，同 PartyStoreHK／Ledger AI 並存）
- **Dashboard**：PROGRESS.md → 靜態 status 頁 deploy 上 VPS，我每步更新

## 多用戶同步設計（唔係單機 app）

- **Server-authoritative**：唯一真相喺 server DB；Web/iOS 只係 cache＋view——離線可以睇，改嘢一定要過 API
- **Multi-tenant from day 1**：所有 table 以 user/calendar scope，由第一個 schema 版本就係咁，冇「單機版」假設
- **權限**：calendar 級角色（creator/member）；每個 API request 都檢查 membership，唔係淨靠 client 收埋
- **同步**：v1 REST＋ETag/poll（iOS 背景拉更新）；起量後 v2 WebSocket/SSE
- **Push**：APNs（iOS）＋ web push——event 新建/改動/留言/邀請即時推俾其他成員（Phase 2.6）
- **iOS 上架路徑**：TestFlight 內部 → 外部 → App Store；Sign in with Apple 係上架硬性要求，1.1 Auth 已包

## 每個功能 task 嘅內部交付順序

API endpoint → Web UI → iOS UI → MCP tool → webhook event → 我親自驗收 → 更新進度表＋Telegram 報告

## 決定記錄

- 產品名：**MangoTime**（2026-11-02 Simon 拍板）
- server 語言：**TypeScript**（Simon 問 PM 意見後確認，2026-11-02）
