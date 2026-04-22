# CPBL 2026 進場倒數

單頁 HTML 工具，規劃 2026 中華職棒一軍例行賽看球行程。

- 線上：https://tiffany-trident.github.io/cpbl-planner/
- GitHub：https://github.com/tiffany-trident/cpbl-planner

---

## 開工前必讀

每次 session 一開始，以及每個任務動手前，**先依任務類型讀對應 docs**，不要憑印象推論。

| 任務類型 | 必讀 |
|---------|------|
| UI / 視覺 / 字體 / 圖示 | [docs/uidesign.md](docs/uidesign.md) / [docs/uidesign-changelog.md](docs/uidesign-changelog.md) |
| 功能規劃 / 黏著度 Roadmap | [docs/engagement.md](docs/engagement.md) |
| 現有功能清單 | [docs/features.md](docs/features.md) |
| 資料來源 / API / RAW_DATA 格式 | [docs/data-source.md](docs/data-source.md) |
| 自動更新 / 部署方案 | [docs/scoreupdate.md](docs/scoreupdate.md) / [docs/scoreupdate-history.md](docs/scoreupdate-history.md) |
| 天氣預報 | [docs/weather.md](docs/weather.md) |
| 賽事記錄 | [docs/briefings.md](docs/briefings.md) |
| 主場主題日 | [docs/theme-days.md](docs/theme-days.md) |
| 外部連結資料（購票網站、高鐵站對應） | [docs/external-links.md](docs/external-links.md) |

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
