# 比分自動更新：歷史方案評估（失敗記錄）

原本設計：GitHub Actions 每日 23:00 執行 `scripts/fetch-scores.sh` 抓 CPBL API 更新 `RAW_DATA` 並 commit。實際每天 6 秒內失敗——**CPBL 封鎖境外 IP**（GitHub Actions runner 在美歐），只有本地台灣 IP 能跑。

目前採用方案 D（本機 Windows Task Scheduler），詳見 [scoreupdate.md](scoreupdate.md)。本文保留所有失敗方案的細節，以免將來再嘗試一次。

## 測試過的繞路方法（全失敗）

### 瀏覽器 CORS proxy

2026-04-13 實測：

| Proxy | 錯誤 |
|-------|------|
| `api.allorigins.win/raw` | 沒回 CORS header + 408 Timeout |
| `corsproxy.io/?<url>` | URL 格式失效，404 |
| `proxy.cors.sh` | 需要付費 API key，429 |

即使找到能用的 proxy，更根本的問題是：CPBL 用 ASP.NET Core antiforgery，token 和 cookie 要配對；免費 proxy 不維持跨請求 session，POST 會失敗。

### 方案 A：Cloudflare Worker（2026-04-13 失敗）

Worker 已部署並完整除錯，確認被 CPBL IP 層封鎖：

| Path | 結果 |
|------|------|
| `GET /` | 200 ✅ |
| `GET /schedule` | 404 |
| `GET /Schedule`（大寫 S） | 404 |
| `POST /schedule/getgamedatas` | 404 |

CPBL 對 Cloudflare 全球 outbound IP 精準封鎖 `/schedule*`，只放行首頁。IP 層封鎖，換 header/cookie/參數都無效。

[cloudflare-worker/worker.js](../cloudflare-worker/worker.js) 保留作失敗記錄。

### 方案 A5：Google Apps Script（2026-04-13 失敗）

透過 `UrlFetchApp` 從 Google outbound IP 打 CPBL，探查 20 條路徑：

- `/` → 200（但不發 antiforgery cookie）
- `/schedule`, `/standings`, `/team`, `/box/index`, `/stats/*`, `/member` 等 → 全 404

CPBL 對 Google IP 封鎖比 Cloudflare 還徹底。首頁 hidden token 送去 POST 也因無 cookie 配對回 500。

[google-apps-script/Code.gs](../google-apps-script/Code.gs) 保留，含 probe 工具可重測。

### 未測試的替代路線

| 方案 | 做法 | 未測原因 |
|------|------|---------|
| A2：亞洲 serverless（Zeabur 🇹🇼 / fly.io 🇭🇰🇯🇵） | 台灣/亞洲機房 IP 可能放行 | 方案 D 已足用，未驗證 |
| A3：CPBL 其他端點 | `/stats/*`、手機 App API、政府開放資料 | 複雜度高，未試 |
| A4：GitHub Actions self-hosted runner | 本機當 runner 跑原 workflow | 等同方案 D，無額外好處 |
| B：純手動 `git push` | 每次本機跑 + push | 手機看不到即時更新 |
| C：按鈕跳 CPBL 官網 | 放棄資料同步 | 體驗差 |

## 歷史部署步驟（參考用）

### Cloudflare Worker

1. dash.cloudflare.com 註冊 → Workers & Pages → Create Worker → 取名 `cpbl-fetch` → Deploy
2. Edit code → 貼 [cloudflare-worker/worker.js](../cloudflare-worker/worker.js) → Deploy
3. 訪問 `https://cpbl-fetch.<account>.workers.dev` 測試（實測回 404）
4. 若成功：編輯 html 的 `CPBL_WORKER_URL` 填入 URL → commit

### Google Apps Script

1. script.google.com → 新增專案 → 貼 [google-apps-script/Code.gs](../google-apps-script/Code.gs)
2. 部署 → 新增部署作業 → 網頁應用程式 → 執行身分「我」、存取權限「任何人」→ 部署 → 首次授權
3. 複製 URL（`https://script.google.com/macros/s/xxx/exec`）→ 瀏覽器測試應回 `{"ok":true,"count":364,...}`
4. 若成功：html 的 `CPBL_WORKER_URL` 填此 URL

改 Code.gs：部署 → 管理部署作業 → 編輯 → 版本選新版本 → 部署（URL 不變）。

## 移除的 UI

網頁曾有「🔄 更新比分」按鈕（嘗試瀏覽器端呼叫 proxy / Worker），已於 commit `6871437` 移除——按鈕、CSS、`CPBL_WORKER_URL` 常數、`refreshScores()` 函式一併拆掉。

## 相關檔案

- [cloudflare-worker/worker.js](../cloudflare-worker/worker.js) — 方案 A 程式碼（已失敗）
- [google-apps-script/Code.gs](../google-apps-script/Code.gs) — 方案 A5 程式碼（已失敗）
- [.github/workflows/update-scores.yml](../.github/workflows/update-scores.yml) — workflow（schedule 已停用，保留 workflow_dispatch）
- [scripts/fetch-scores.sh](../scripts/fetch-scores.sh) — 原 bash 版本，被 PowerShell 版本取代
