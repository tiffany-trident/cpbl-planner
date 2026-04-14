# 比分自動更新方案評估

---

## 🔖 進度記錄(2026-04-14 更新)

**現行採用:方案 D(本機 Windows 工作排程器)**

### ✅ 已完成
- [scripts/update-scores.ps1](scripts/update-scores.ps1) — PowerShell 版抓取腳本(取代 bash + node,零外部依賴)
- [scripts/update-scores.bat](scripts/update-scores.bat) — Task Scheduler 呼叫的包裝 bat(ASCII 純淨版,避免中文編碼問題)
- 手動執行驗證成功:commit `dfc9df3`,364 場資料已 push 到 GitHub
- Git 認證(push 不需輸入密碼)已設定
- Task Scheduler 已修正並正常運作(2026-04-14 10:52 自動執行成功)
- ConvertTo-Json 格式問題已修正,網頁資料顯示正常(commit `c87571d`)

### 🔧 已解決的問題

**問題 1:Task Scheduler `0x80070002` 找不到檔案**
- 原因:路徑含空格(`AI Work\baseball plan`),Task Scheduler 在空格處截斷,把 `C:\Trident\AI` 當程式、`Work\baseball plan\...` 當引數
- 修正:動作改為程式 `cmd.exe`,引數 `/c "C:\Trident\AI Work\baseball plan\scripts\update-scores.bat"`,開始位置不變

**問題 2:網頁資料全部消失(RAW_DATA 格式錯誤)**
- 原因:PowerShell `,$row | ConvertTo-Json -Compress` 透過管線傳陣列會被包成 `{"value":[...],"Count":12}` 物件,JS 解析失敗
- 修正:改用 `ConvertTo-Json -InputObject $row -Compress` 直接傳入,輸出純陣列格式

### 🔜 待辦
- [x] ~~決定網頁上「🔄 更新比分」按鈕處置~~ → 已移除按鈕、CSS、JS（refreshScores + CPBL_WORKER_URL）
- [ ] (選配)加 `.gitattributes` 消除 LF→CRLF 警告

---

## 背景

原本設計：GitHub Actions 每日 23:00 執行 `scripts/fetch-scores.sh`，抓 CPBL API 更新 `RAW_DATA` 並 commit 回 repo。

**實際狀況**：workflow 從建立以來每天失敗（6 秒內失敗）。

## 根因

CPBL 官網 `www.cpbl.com.tw` 封鎖境外 IP（GitHub Actions 的 Ubuntu runner 位於美國/歐洲），`curl` 拿不到正常頁面 → token 解析失敗 → `set -euo pipefail` 觸發 exit 1。

本地（台灣 IP）執行腳本正常。

## 已做的處置

- 移除 `.github/workflows/update-scores.yml` 的 `schedule:` 區塊，停止每天寄失敗通知信
- 保留 `workflow_dispatch`（手動觸發），雖然實際也會失敗
- 新增網頁「🔄 更新比分」按鈕，嘗試從瀏覽器透過 CORS proxy 抓取——**實測失敗**

## 為什麼瀏覽器方案也失敗

實測錯誤（2026-04-13 on GitHub Pages）：

| Proxy | 錯誤 |
|-------|------|
| `api.allorigins.win/raw` | 沒回 `Access-Control-Allow-Origin` header，瀏覽器 CORS 擋 + 408 Timeout |
| `corsproxy.io/?<url>` | URL 格式失效，回 404（已改要求 `?url=<url>`，但之前格式也失敗過） |
| `proxy.cors.sh` | 現在需要付費 API key，回 429 Too Many Requests |

即使找到能用的 proxy，還有**更根本的問題**：

> CPBL 使用 ASP.NET Core antiforgery 機制，token 和 cookie 必須配對驗證。
> 免費 CORS proxy 不維持跨請求 session，第二步 POST 的 cookie 抓不回來 → API 會回 `Success=false`。

## 三條可選路線

### 方案 A：Cloudflare Worker（推薦長期方案）

**做法**：
1. 免費註冊 Cloudflare 帳號
2. 建立一個 Worker（免費版 100k requests/日，夠用）
3. 貼上程式碼：Worker 在伺服器端執行兩步 fetch，維持 cookie，回傳 JSON
4. 得到固定 URL（如 `cpbl-fetch.xxx.workers.dev`）
5. 網頁按鈕改呼叫這個 Worker URL

**優點**：
- 完全解決 cookie 綁定問題
- 不依賴會掛掉的免費 proxy
- 免費、可控

**缺點**：
- 需要一次性 5-10 分鐘設定 Cloudflare 帳號
- Worker 若從 Cloudflare 的歐美機房打 CPBL，**可能同樣被擋**
  - 需測試 Cloudflare Worker 的 outbound IP 是否被 CPBL 放行
  - 若被擋，可考慮 Cloudflare Worker + 指定台灣區域（Workers 預設會就近執行，但 CPBL 的封鎖規則不明）

**備註**：Cloudflare 節點遍佈全球包含台灣，outbound 請求的 IP 來源可能是台灣節點，要實測才知道

### 方案 B：移除按鈕 + 手動更新

**做法**：
- 把 `cpbl-planner.html` / `index.html` 的 refresh button 和 `refreshScores()` 函式拆掉
- 賽季中要更新時，本機執行 `bash scripts/fetch-scores.sh`（需先裝 Node.js）+ `git push`

**優點**：立即止血、無依賴
**缺點**：每次手動、電腦要裝 Node.js

### 方案 C：改成「前往 CPBL 官網」快捷按鈕

**做法**：
- 把按鈕文字改成「查看 CPBL 官方賽程」
- 點擊直接開新分頁到 `https://www.cpbl.com.tw/schedule`
- 不做資料同步，純粹方便跳轉

**優點**：100% 可靠、零維護
**缺點**：看到的是 CPBL 官網頁面，不是在自己的規劃器裡看到新比分

## 方案 A 實測結果（2026-04-13）：**失敗**

Cloudflare Worker 已部署並完整除錯，**確認被 CPBL 網路層封鎖**，無法繞過：

| Path | 結果 |
|------|------|
| `GET /schedule` | 404（純文字 `NOT FOUND`） |
| `GET /schedule/index` | 404 |
| `GET /Schedule` | 404 |
| `GET /` | 200（拿得到 token + cookie） |
| `POST /schedule/getgamedatas` | 404 |

**結論**：CPBL 對 Cloudflare 全球 outbound IP 精準封鎖 `/schedule*` 路徑（包含 API），只放行首頁。這是 IP 層封鎖，換 header、加 cookie、改參數都無效。

**Cloudflare Worker 帳號處置**：
- 留著：之後可代理其他 API、部署 Pages、用免費 DNS
- 刪除：CF Dashboard → Workers & Pages → Delete（完全免費，不會有費用）

---

## 後續可選方案

### 方案 A5：Google Apps Script 當跳板（已失敗）

**2026-04-13 實測結果**：Google Apps Script 透過 `UrlFetchApp` 從 Google outbound IP 打 CPBL，探查 20 條路徑：

| Path | Status | 有 Token | 有 Cookie |
|------|--------|---------|----------|
| `/` | 200 ✅ | 僅 hidden input（登入表單用） | **無 Set-Cookie** |
| `/schedule`, `/standings`, `/team`, `/box/index`, `/stats/*`, `/member`, `/member/login`, `/ticket`, `/live`, `/news`, `/about`, `/elect`, `/history`, `/home` 等 | 404 ❌ | — | — |

**結論**：
1. CPBL 對 Google IP 封鎖比 Cloudflare 還徹底，除了 `/` 其他全 404
2. `/` 完全不發 antiforgery cookie，沒有 cookie 就無法通過 POST 驗證
3. 即便把首頁 hidden token 送去 POST，因無 cookie 配對，伺服器回 500（antiforgery 驗證失敗）

**保留**：[google-apps-script/Code.gs](google-apps-script/Code.gs) 保留作為失敗記錄,含 probe 工具可重測。

---

### ~~方案 A5：Google Apps Script 當跳板~~（原始計畫，已被上方失敗記錄取代）

**原理**：CPBL 很難封鎖 Google IP 區段（會波及 Googlebot/Gmail 等正常服務）。把兩步驟 fetch 搬到 GAS 的 `UrlFetchApp` 執行，透過 Web App 部署成公開 URL，網頁按鈕改打這個 URL。

**優點**：
- Google outbound IP 幾乎不可能被整段封（跟 CF IP 段不同）
- 免費額度 20,000 UrlFetchApp/日，綽綽有餘
- 無需電腦開機，可靠度高
- 程式碼邏輯幾乎與 Worker 版本一樣，已備妥 [google-apps-script/Code.gs](google-apps-script/Code.gs)

**缺點**：
- Cold start 約 1-3 秒
- GAS Web App URL 會 302 到 `script.googleusercontent.com`，極少數瀏覽器可能有怪問題

**部署步驟**：

1. 到 https://script.google.com/ 用 Google 帳號登入 → **新增專案**
2. 把檔名 `Code.gs` 內容清空，貼上 [google-apps-script/Code.gs](google-apps-script/Code.gs) 整份
3. 右上 **部署 → 新增部署作業**
   - 類型：**網頁應用程式**
   - 執行身分：**我**
   - 存取權限：**任何人**（不需登入）
   - 點 **部署**，首次會要求授權 → 同意
4. 複製產生的網頁應用程式 URL（形如 `https://script.google.com/macros/s/AKfycb.../exec`）
5. 直接在瀏覽器開那個 URL 測試，預期：
   ```json
   {"ok":true,"count":364,"rows":[...]}
   ```
   若回 `{"ok":false,"error":"..."}`：看 error 訊息判斷是 token 抓不到還是 API 404
6. 成功後，編輯 [cpbl-planner.html](cpbl-planner.html) 與 [index.html](index.html)，搜尋 `CPBL_WORKER_URL` 填入：
   ```js
   const CPBL_WORKER_URL = 'https://script.google.com/macros/s/AKfycb.../exec';
   ```
7. Commit + push，GitHub Pages 更新後網頁按鈕即可運作

**後續若要改程式碼**：改完 `Code.gs` → **部署 → 管理部署作業 → 編輯（鉛筆）→ 版本選新版本 → 部署**（URL 不變）

### 方案 A2：換亞洲節點 serverless

CF 全球 IP 被擋，但**台灣/亞洲機房**的 serverless 可能放行。程式碼幾乎不用改。

| 平台 | 區域 | 免費額度 | 適配性 |
|---|---|---|---|
| **Zeabur** | 🇹🇼 台灣 Hinet | 有免費方案 | ⭐⭐⭐ 最推薦 |
| **fly.io** | 🇭🇰 HKG / 🇯🇵 NRT | 3 個 shared VM 免費 | ⭐⭐ 亞洲 IP |
| **Deno Deploy** | 全球（無指定） | 100 萬請求/月 | ⭐ 不一定亞洲 |

### 方案 A3：找 CPBL 其他未被擋的端點

- `/stats/*`（打擊/投手數據頁）可能未被擋
- CPBL 手機 App 用的 API 端點（需抓封包）
- 政府開放資料（data.gov.tw，但通常無即時比分）

### 方案 D：本機 Windows 工作排程器（⭐ 現行採用方案）

本機台灣 IP 是目前唯一驗證能打通 CPBL 的路徑。用 Windows 內建工作排程器自動化。

**已備妥包裝腳本**：[scripts/update-scores.bat](scripts/update-scores.bat)
- 呼叫 `fetch-scores.sh` 抓最新比分
- 若 `index.html` / `cpbl-planner.html` 有變更才 commit + push
- Log 寫到 `logs/update-scores.log`

**Task Scheduler 設定步驟**：

1. 開啟 **工作排程器**（Win + R → `taskschd.msc`）
2. 右邊「**建立基本工作**」
3. **名稱**：`CPBL 比分自動更新`
4. **觸發程序**：每天 → 開始時間 **09:00**（比賽前一晚跑完，早上 9:00 資料最穩）
5. **動作**：啟動程式
   - 程式或指令碼：`C:\Trident\AI Work\baseball plan\scripts\update-scores.bat`
   - 起始位置：`C:\Trident\AI Work\baseball plan`（⚠️ 一定要填）
6. 勾「**開啟此工作的內容對話方塊**」→ 完成
7. 內容對話方塊裡切到 **設定** 分頁：
   - ✅ 勾「**如果排程工作開始時間已過,立即啟動工作**」
   - ✅ 勾「**如果工作失敗,重新啟動每**」：10 分鐘、最多嘗試 3 次
   - ✅ 勾「**如果工作執行超過**」：1 小時（超時殺掉）
8. 切到 **一般** 分頁 → 勾「**以最高權限執行**」（避免 git push 權限問題）

**前置檢查**：
- Git for Windows 已安裝在預設路徑 `C:\Program Files\Git\`（若自訂路徑,編輯 `update-scores.bat` 最上方兩行）
- `git push` 必須已設定好認證（SSH key 或 credential manager）→ 先在 cmd 手動跑一次 `git push` 確認不會跳登入

**手動測試**：在 cmd 跑 `scripts\update-scores.bat` 確認會 push 成功,再設排程。

**查 log**：[logs/update-scores.log](logs/update-scores.log)（每次執行追加時間戳 + 輸出）

**缺點**：電腦關機/沒網路時那天會漏,但「錯過補跑」設定會在下次開機後自動執行。

### 方案 A4：GitHub Actions self-hosted runner

回到 GitHub Actions 排程，但用本機當 runner：
- 安裝 self-hosted runner（5 分鐘）
- 現有 workflow 照舊跑，改在本機台灣 IP 執行
- 相當於方案 D 但保留 GitHub Actions 的配置結構

### 方案 B：移除按鈕 + 純手動

賽季中要更新時：本機跑 `bash scripts/fetch-scores.sh` + `git push`。
每次需要在那台有腳本的電腦上操作，手機/其他裝置看不到即時更新。

### 方案 C：按鈕改成「查看 CPBL 官網」跳轉

100% 可靠、零維護，但看到的是 CPBL 官網頁面，不是在自己規劃器裡。

---

## 建議優先順序

境外 serverless 全軍覆沒(CF Worker、GAS 都被擋),**改走方案 D**。

1. ✅ **方案 D（Windows 工作排程器)** — 本機台灣 IP,已驗證可通,目前採用
2. D 不行再考慮 **方案 A2(Zeabur 台灣節點)** — 台灣機房 IP,可能也被擋,未驗證
3. 全部失敗 → **方案 C（跳轉連結)** — 直接放棄資料同步

---

## 參考：Cloudflare Worker 部署步驟（已失敗，保留記錄）

<details>
<summary>展開</summary>

### 1. 註冊並建立 Worker

1. 到 https://dash.cloudflare.com/ 註冊（免費）
2. 左邊選單 → **Workers & Pages** → **Create** → **Create Worker**
3. 取個名字（例如 `cpbl-fetch`）→ **Deploy**
4. 部署完點 **Edit code**

### 2. 貼上程式碼

- 清空編輯器，貼上 [cloudflare-worker/worker.js](cloudflare-worker/worker.js) 整份內容
- 右上 **Deploy**

### 3. 測試 Worker

訪問 `https://cpbl-fetch.<你的帳號>.workers.dev`，
預期 `{ok:true, count:364, rows:[...]}`，
**實測回 `{ok:false, error:"POST /getgamedatas HTTP 404"}`**。

### 4. 填入 Worker URL（若成功）

編輯 [cpbl-planner.html](cpbl-planner.html) 和 [index.html](index.html)，
搜尋 `CPBL_WORKER_URL`：

```js
const CPBL_WORKER_URL = 'https://cpbl-fetch.xxxxx.workers.dev';
```

### 5. Commit & Push

```bash
git add cpbl-planner.html index.html
git commit -m "設定 CPBL Worker URL"
git push
```

GitHub Pages 更新後，網頁「🔄 更新比分」按鈕即可運作。

</details>

## 相關檔案位置

- **Windows 排程包裝腳本(方案 D)**：[scripts/update-scores.bat](scripts/update-scores.bat)
- GAS 程式碼(方案 A5 已失敗,保留參考)：[google-apps-script/Code.gs](google-apps-script/Code.gs)
- Worker 程式碼（方案 A 已失敗，保留參考）：[cloudflare-worker/worker.js](cloudflare-worker/worker.js)
- Workflow（已停用排程）：[.github/workflows/update-scores.yml](.github/workflows/update-scores.yml)
- 本機抓取腳本：[scripts/fetch-scores.sh](scripts/fetch-scores.sh)
- 按鈕 UI 與 JS：[cpbl-planner.html](cpbl-planner.html) / [index.html](index.html)（搜尋 `refresh-btn` 或 `refreshScores`）
