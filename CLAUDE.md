# CPBL 2026 進場倒數

單頁 HTML 工具，規劃 2026 中華職棒一軍例行賽看球行程。

- 線上：https://tiffany-trident.github.io/cpbl-planner/
- GitHub：https://github.com/tiffany-trident/cpbl-planner

---

## 開工前必讀（硬規則）

**每次 session 一開始、每個 Step / 子任務動手前、以及選定任何 icon / 視覺元件前**，先依任務類型讀對應文件。**不得憑印象、記憶或訓練語料推論**（例如看到「收藏」就用 ⭐、看到「打卡」就用 📍 — 這類假設在本專案幾乎都是錯的）。

| 任務類型 | 必讀 |
|---------|------|
| UI / 視覺 / 字體 / 色彩系統 | [docs/uidesign.md](docs/uidesign.md) / [docs/uidesign-changelog.md](docs/uidesign-changelog.md) |
| **Icon 選用（含 SVG sprite / 客製符號 ID）** | **[design/phase1-2-preview.html](design/phase1-2-preview.html) 最上方的 `<defs>` sprite 區**（含 bb-favorite、bb-checkin 等客製 symbol 的正規定義）+ 下文「客製 icon 命名表」 |
| 功能規劃 / 黏著度 Roadmap | [docs/engagement.md](docs/engagement.md) |
| 現有功能清單 | [docs/features.md](docs/features.md) |
| 資料來源 / API / RAW_DATA 格式 | [docs/data-source.md](docs/data-source.md) |
| 自動更新 / 部署方案 | [docs/scoreupdate.md](docs/scoreupdate.md) / [docs/scoreupdate-history.md](docs/scoreupdate-history.md) |
| 天氣預報 | [docs/weather.md](docs/weather.md) |
| 賽事記錄 | [docs/briefings.md](docs/briefings.md) |
| 主場主題日 | [docs/theme-days.md](docs/theme-days.md) |
| 外部連結資料（購票網站、高鐵站對應） | [docs/external-links.md](docs/external-links.md) |

### 客製 icon 命名表（正規定義在 `design/phase1-2-preview.html` sprite）

選 icon 前**一律先查此表與視覺稿 sprite**，不要自作主張選 emoji 或別的圖庫 icon。

| Symbol ID | 用途 | 來源 |
|-----------|------|------|
| `bb-favorite` | 場次收藏（⭐ 的正規替代圖） | svgrepo 139073（棒球+投球動線） |
| `bb-checkin` | 觀戰打卡（📍 的正規替代圖） | 以 `design/phase1-2-preview.html` 最新定義為準 |
| `cap-mainteam` | 戰績表主隊標記 | Phosphor `baseball-helmet-fill`（MIT） |

若 `design/phase1-2-preview.html` 的 sprite 有更新（例如使用者換圖），**以視覺稿為最新真實來源**，主程式 `index.html` 需同步更新 sprite。

## 設計原則

### 調性
- 參考 **Snoopy Museum Tokyo 的「卡通活潑」感**（不是博物館典雅）
- **絕對不使用 Snoopy 或任何版權角色 IP** — 只取調性，不用角色
- 彩色插畫 > 線條圖示，Tabler Icons 只做 UI 輔助（filter、search、arrow），不當主要視覺

### 配色
- 淺色清爽為主，避免色彩太重
- 赤陶紅 `#C2573A` 為重點色
- 完整色彩系統見 [docs/uidesign.md](docs/uidesign.md)

### 字體
- **jf-openhuninn（粉圓）為主**，Inter + Noto Sans TC 為輔
- **避免襯線體 Noto Serif TC**（偏離卡通方向）
- 日文字體（Hachi Maru Pop 等）**不含繁中字形**，不能用於中文顯示

### 素材授權
- 使用 Flaticon Free、CC BY 等授權素材時，**production 部署前必須加 attribution**
- 目前使用清單與 attribution 條款見 memory `project_flaticon_attribution.md`

## 資料正確性（硬規則）

- **絕對不可自行編造或猜測比賽結果**，所有已完賽資料必須來自 CPBL 官方 API
- API 回傳是**唯一真實來源**，不可從記憶或推測產生
- 驗證資料時應重新呼叫 API 比對

## Git 工作流程（硬規則）

- **所有功能開發、調整、修改一律走 feature branch**，不得直接改在 `main` 上
- 分支命名：`feat/<功能名>`（新功能）／`fix/<問題名>`（修 bug）／`chore/<雜項>`（文件、設定）
- 流程：從 `main` 拉分支 → 本機修改 + 瀏覽器驗證 → push → merge 回 `main` → GitHub Pages 自動部署
- **merge 回 `main` 前必須在本機開瀏覽器驗證**（與部署原則「改動後自我驗證」合併要求）
- 不滿意可直接砍分支或 reset，不會污染 `main` 與線上部署
- GitHub Actions 自動更新 workflow 只會動 `main` 的 `games_data.json` 與兩份 HTML；feature branch 存活期間需自行處理 merge 衝突

## 部署原則

- GitHub Pages 從 `main` 分支 `index.html` 部署
- **修改 `cpbl-planner.html` 後必須同步到 `index.html` 再 push**
- GitHub Actions 自動更新 workflow 會同時更新兩個檔案
- GitHub Pages 有瀏覽器快取，push 後使用者可能需要 Ctrl+Shift+R 才能看到最新資料
- **改動 CSS / 字體 / CDN 後必須自行驗證生效**，不可只靠推論假設
- 現行自動更新方案為本機 Windows Task Scheduler（境外 serverless 全數失敗，見 [docs/scoreupdate-history.md](docs/scoreupdate-history.md)）

## 目錄結構（概要）

| 路徑 | 用途 |
|-----|------|
| `index.html` / `cpbl-planner.html` | 主程式檔（兩者需保持同步） |
| `data/` | 資料 JSON 與快取（`games_data.json`、`briefings.json`） |
| `scripts/` | 自動更新抓取腳本（`fetch-scores.sh`、`update-scores.ps1`、`update-scores.bat`） |
| `docs/` | 功能規格、架構、設計文件 |
| `design/` | Pencil 設計檔、HTML 視覺稿 |
| `icon-preview/` | icon 素材庫 + 預覽頁 |
| `images/` | 生成圖片素材 |
| `cloudflare-worker/` / `google-apps-script/` | 境外 serverless 嘗試（已驗證失敗） |
| `.github/workflows/` | GitHub Actions（目前排程已停用） |
