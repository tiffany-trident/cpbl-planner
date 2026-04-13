# CPBL 2026 看球行程規劃器

單頁 HTML 工具，篩選 2026 中華職棒一軍例行賽場次，規劃看球行程並查詢比賽結果。

- 線上：https://tiffany-trident.github.io/cpbl-planner/
- GitHub：https://github.com/tiffany-trident/cpbl-planner

## 資料來源

- CPBL 官網 API `POST /schedule/getgamedatas`（需 `RequestVerificationToken`）
- 取得 token：先 GET `/schedule` 取得 cookie 與頁面內嵌 token
- 364 場（含延賽），6 隊，11 球場，2026-03-28 ~ 2026-09-28
- 資料內嵌於 HTML，各隊 logo 引用 cpbl.com.tw

## RAW_DATA 格式

```
[日期, 時間, 客隊, 主隊, 球場, 客分, 主分, 勝投, 敗投, 救援, MVP, GameResult]
```

- `GameResult`: `"0"` 已完賽 / `"1"` 延賽取消 / `""` 未賽

## 功能

- 隊伍／對手多選 chip 按鈕，球場、月份下拉篩選
- 週末／週末+國定假日篩選，台灣 2026 國定假日內建
- 場次狀態三段切換：未來場次（預設）／全部／已結束
- 已完賽：比分（勝方奶茶棕、敗方灰）+ W/L/SV/MVP 彩色 pill 標籤
- 延賽：紫色 badge，不顯示比分
- 今日：橘色 badge + 淡橘背景高亮
- 同日多場分組：桌面版日期僅首場顯示 + 分隔列；手機版日期標題分組
- 狀態 badge 僅「全部」模式顯示
- 統計列：篩選結果／週末／假日依篩選計算；已完賽／未來／延賽從全部資料計算
- 各隊戰績總覽（頁頂，依勝率排序）
- 購票按鈕：未來非延賽場次，依主場球隊連結售票網站
- 高鐵訂票按鈕：未來非延賽場次，依球場對應高鐵站（花蓮不顯示）

## 設計風格

參考 Snoopy Museum Tokyo 風格，溫暖卡片式設計。

- 暖色調：背景 `#FDFCFA`、卡片 `#FFF`、主文字 `#4A3728`、重點色 `#C2573A`（赤陶紅）
- 字體：Inter + Noto Sans TC；Hero 標題用 Noto Serif TC
- 結構：Nav（頂部）→ Hero（置中標題 + emoji 裝飾 🏏⚾）→ 戰績 → 篩選 → 統計 → 卡片網格 → 深棕頁尾
- **統一卡片網格**（桌面 3 欄 / 平板 2 欄 / 手機 1 欄），不再使用表格
- 卡片結構：頂部欄（時間 + 球場 `◉`）→ 對戰區（logo 圓形 + VS/比分）→ 詳情 pill → 底部（球場 + 標籤）→ 按鈕
- 日期分組：每日一個 `.date-group`，有橫線延伸的日期標題
- 卡片特殊狀態：
  - 今日 → `card-top-today` 橘色頂部背景
  - 延賽 → `card-top-postponed` 紫色頂部背景 + 延賽 badge
  - 已完賽 → 大字比分（`26px` 粗體），勝方赤陶紅、敗方灰
- 圓潤風格：Chip `border-radius: 22px`、按鈕 `20px`、下拉/Toggle `12px`、卡片 `16px`
- Toggle 採膠囊 + 白色 active 區塊樣式（iOS 風格）
- Badge 色系：週六藍、週日紅、假日赤陶、今日橘、延賽紫、未來綠、已結束灰
- 統計列：項目用圓點 `●` 分隔
- 頁尾：深棕 `#3D3122` 背景 + 裝飾元素 `● —— ◆ —— ●`

## 檔案結構

- `index.html` — 部署主檔（與 cpbl-planner.html 同步）
- `cpbl-planner.html` — 開發檔
- `games_data.json` — 賽程原始資料備份
- `scripts/fetch-scores.sh` — 資料抓取腳本
- `.github/workflows/update-scores.yml` — 自動更新 workflow

## 自動更新

- GitHub Actions 每日台灣時間 23:00（UTC 15:00）執行，也可手動觸發
- 流程：CPBL API → RAW_DATA → 更新 index.html + cpbl-planner.html
- 僅資料有變更時才 commit

## 各隊購票連結

| 球隊 | 網址 |
|------|------|
| 樂天桃猿 | https://ticket.ibon.com.tw/Index/Sport |
| 中信兄弟 | https://tix.brothers.tw/ |
| 統一7-ELEVEn獅 | https://ticket.ibon.com.tw/Index/Sport |
| 富邦悍將 | https://guardians.fami.life/ |
| 味全龍 | https://tix.wdragons.com/ |
| 台鋼雄鷹 | https://ticket.tsghawks.com/ |

## 球場高鐵站對應

| 球場 | 高鐵站 |
|------|--------|
| 大巨蛋 / 天母 | 台北 |
| 新莊 | 板橋 |
| 樂天桃園 | 桃園 |
| 洲際 | 台中 |
| 嘉義市 | 嘉義 |
| 亞太主 | 台南 |
| 澄清湖 | 左營 |
| 斗六 | 雲林 |
| 花蓮 | 無高鐵站 |

- 高鐵訂票連結：`https://irs.thsrc.com.tw/IMINT/`（不支援 URL 參數帶入目的站）

## 資料正確性

- **絕對不可自行編造或猜測比賽結果**，所有已完賽資料必須來自 CPBL 官方 API
- API 回傳為唯一真實來源，不可從記憶或推測產生
- 驗證資料應重新呼叫 API 比對

## 部署

- GitHub Pages 從 `main` 分支 `index.html` 部署
- 修改 `cpbl-planner.html` 後需同步到 `index.html` 再 push
- GitHub Actions 自動更新時會同時更新兩個檔案
