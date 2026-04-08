# CPBL 2026 看球行程規劃器

## 專案簡介

一個單頁 HTML 工具，可快速篩選 2026 中華職棒一軍例行賽場次，方便規劃看球行程，同時也能查詢已結束比賽的結果。

- 線上網址: https://tiffany-trident.github.io/cpbl-planner/
- GitHub: https://github.com/tiffany-trident/cpbl-planner

## 資料來源

- 從 CPBL 官網 API (`POST /schedule/getgamedatas`) 抓取，需帶 `RequestVerificationToken` header
- 取得 token 方式：先 GET `/schedule` 頁面取得 cookie 與頁面中內嵌的 token
- 364 場比賽（含延賽），6 隊，11 球場，日期範圍 2026-03-28 ~ 2026-09-28
- 資料已內嵌於 HTML 中，各隊 logo 引用 cpbl.com.tw

## RAW_DATA 格式

每筆資料為一個陣列，共 12 個欄位：

```
[日期, 時間, 客隊, 主隊, 球場, 客分, 主分, 勝投, 敗投, 救援, MVP, GameResult]
```

- `GameResult`: `"0"` = 已完賽, `"1"` = 延賽/取消, `""` = 未賽
- 未賽的比賽，比分為 0，投手/MVP 為空字串

## 功能

- 隊伍 / 對手多選（chip 按鈕，可同時選多隊交叉篩選）
- 球場、月份下拉篩選
- 週末 / 週末+國定假日篩選
- 場次狀態三段切換：「未來場次」（預設）/「全部」/「已結束」
- 已完賽場次顯示比分（勝方奶茶棕高亮、敗方灰色）
- 已完賽場次顯示勝投(W)、敗投(L)、救援(SV)、MVP 詳情
- 延賽場次顯示紫色「延賽」badge，不顯示比分
- 今日比賽顯示橘色「今日」badge
- 各隊戰績總覽（頁面頂部，依勝率排序）
- 台灣 2026 國定假日內建
- 購票按鈕：僅在未來且非延賽場次顯示，依主場球隊連結至對應售票網站

## 設計風格

- 文青暖色調：背景 `#faf8f5`、重點色 `#b8956a`（奶茶棕），避免冷色系
- 字體：標題用 Inter 無襯線體，內文用 Noto Sans TC
- 棒球元素：Header 右側半透明棒球圓形 + 縫線裝飾，頁尾波浪縫線
- RWD：桌面版表格、手機版（≤768px）卡片式列表
- 對戰組合：logo + 隊名色塊，中間圓形 `@` 分隔，非純文字
- 比分配色：勝方 `#b8956a`（奶茶棕），敗方 `#b0a593`（灰）
- Badge 色系：週六藍、週日紅、假日棕、今日橘、延賽紫、未來綠、已結束灰

## 檔案結構

- `index.html` — 部署用主檔（與 cpbl-planner.html 相同，修改後需同步）
- `cpbl-planner.html` — 原始開發檔
- `games_data.json` — 賽程原始資料（JSON，僅備份用，不影響網頁運作）
- `scripts/fetch-scores.sh` — 資料抓取腳本（從 CPBL API 抓取比分並更新 index.html）
- `.github/workflows/update-scores.yml` — GitHub Actions 自動更新 workflow

## 自動更新機制

- GitHub Actions workflow 每日台灣時間 23:00（UTC 15:00）自動執行
- 執行 `scripts/fetch-scores.sh`：抓取 CPBL API → 轉換為 RAW_DATA → 更新 index.html + cpbl-planner.html
- 腳本需要 `curl` 和 `node`（GitHub Actions ubuntu runner 預設有）
- 也可手動觸發（workflow_dispatch）
- 僅在資料有變更時才 commit

## 各隊購票連結

| 球隊 | 售票平台 | 網址 |
|------|---------|------|
| 樂天桃猿 | ibon 售票 | https://ticket.ibon.com.tw/Index/Sport |
| 中信兄弟 | 中信育樂售票網 | https://tix.brothers.tw/ |
| 統一7-ELEVEn獅 | ibon 售票 | https://ticket.ibon.com.tw/Index/Sport |
| 富邦悍將 | 富邦悍將售票網 | https://guardians.fami.life/ |
| 味全龍 | 味全龍售票網 | https://tix.wdragons.com/ |
| 台鋼雄鷹 | 台鋼雄鷹售票網 | https://ticket.tsghawks.com/ |

## 手動更新賽程

若需手動更新，執行 `bash scripts/fetch-scores.sh`（需要 curl + node 環境），或重新呼叫 CPBL API 並替換 `index.html` 中的 `RAW_DATA` 變數。

## 部署

- GitHub Pages 從 `main` 分支的 `index.html` 部署
- 修改 `cpbl-planner.html` 後需複製到 `index.html` 再 push
- GitHub Actions 自動更新時會同時更新兩個檔案
