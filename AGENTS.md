# AGENTS.md — 俾做嘢嘅 AI agent 讀嘅指引

> 呢個檔案係 Simon 嘅主 agent（Hermes）寫嘅。你做嘢之前**必讀**。最重要嘅一段係「iOS 上架」——前一個 agent 喺呢度撞咗牆。

## 環境硬事實（唔好嘗試繞過）

- 開發機係 **2012 Intel Mac mini，macOS 15.8.1（OpenCore）**
- **冇 Xcode**（得 Command Line Tools，Swift 6.1.2）→ **本機起唔到 IPA**，唔好嘗試 `xcodebuild archive` 喺本機行
- **冇本地簽名證書** → 簽名只可以喺 CI 上面做
- 正確路線：**推上 GitHub → GitHub Actions（macos-15 runner）archive + 上傳 App Store Connect**

## 已驗證成功嘅上架 pipeline（照抄就得）

同機嘅 TankPal 喺 2026-10-15 用呢套成功上咗 TestFlight + App Store 審查。**唔好重新發明，直接參考：**

- Workflow 模板：`/Users/simon/Projects/tankpal/.github/workflows/`
  - `build.yml` — macos-15 + xcodegen + simulator build（無簽名驗證用）
  - `archive.yml` — archive + export IPA + API key 上傳 ASC
  - `asc-setup.yml` — ASC record / IAP 設定
- ASC API key：`~/.appstoreconnect/private_keys/`（AuthKey_*.p8）；issuer 同 key id 喺 key 名同 GitHub secrets
- **macOS runner 喺 private repo 係 10× 收費**——batch push，唔好逐個 commit 推
- 證書有 Apple quota 限制——tankpal 嘅 workflow 已處理（keychain reuse），照抄佢嘅做法

## 完整技能文件（喺呢個 repo 入面）

`docs/agent-skills/` 入面有三份完整 runbook，**做相關步驟前逐字讀**：

1. `ios-app-store-shipping/SKILL.md` — 端到端上架流程（8 個步驟順序、伏位、驗證規矩）
2. `appstore-connect-api/SKILL.md` + `references/api-recipes.md` + `scripts/asc_api.py` — ASC REST API 所有操作（JWT 認證、IAP、metadata、狀態查詢）
3. `ios-clt-typecheck/SKILL.md` — **冇 Xcode 都驗證到 Swift**：CLT whole-module typecheck 做法

## 而家 iOS 上架卡喺邊（2026-11-03 診斷）

1. ❌ repo 未推上 GitHub（`git remote -v` 空）→ CI 根本冇得行
2. ❌ `.github/workflows/ci.yml` 得 server + web，**冇 iOS build/archive job**
3. ⚠️ `ios/MangoTime.xcodeproj/project.pbxproj` 係手砌 333 行——手寫 pbxproj 極易壞。**強烈建議轉 xcodegen**（寫 `project.yml`，xcodegen 產生 xcodeproj；tankpal 就係咁做）

## 上架要做嘅事（按次序）

1. `docs/agent-skills/ios-clt-typecheck` 嘅方法本地驗證 Swift 0 errors / 0 warnings
2. 手砌 pbxproj → xcodegen `project.yml`（參考 `/Users/simon/Projects/tankpal/project.yml`）
3. 開 private GitHub repo，推 code
4. 抄 tankpal 嘅 `build.yml` + `archive.yml` 過嚟，改 project/scheme 名（MangoTime）
5. 設 GitHub secrets（ASC key、證書、provisioning——參考 tankpal repo settings）
6. 行 green → IPA 自動上 TestFlight → Simon 手機收測試通知

## 規矩

- Secrets 淨係擺 `.env` / GitHub secrets，**永遠唔好寫入 code 或 docs**
- 每完成一步更新 `PROGRESS.md` 同喺 Telegram 報告（項目慣例）
- 唔好郁 server/ web/ mcp/ 入面同你任務無關嘅嘢
