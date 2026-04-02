# CPBL 2026 看球行程規劃器

## 專案簡介

一個單頁 HTML 工具，可快速篩選 2026 中華職棒一軍例行賽場次，方便規劃週末或假日看球行程。

- 線上網址: https://tiffany-trident.github.io/cpbl-planner/
- GitHub: https://github.com/tiffany-trident/cpbl-planner

## 資料來源

- 從 CPBL 官網 API (`POST /schedule/getgamedatas`) 抓取，需帶 `RequestVerificationToken` header
- 360 場比賽，6 隊，11 球場，日期範圍 2026-03-28 ~ 2026-09-28
- 資料已內嵌於 HTML 中，各隊 logo 引用 cpbl.com.tw

## 功能

- 隊伍 / 對手多選（chip 按鈕，可同時選多隊交叉篩選）
- 球場、月份下拉篩選
- 週末 / 週末+國定假日篩選
- 只看未來場次（預設開啟）
- 台灣 2026 國定假日內建

## 設計風格

- 文青暖色調：背景 `#faf8f5`、重點色 `#b8956a`（奶茶棕），避免冷色系
- 字體：標題用 Noto Serif TC 襯線體，內文用 Noto Sans TC
- 棒球元素：Header 右側半透明棒球圓形 + 縫線裝飾，頁尾波浪縫線
- RWD：桌面版表格、手機版（≤768px）卡片式列表
- 對戰組合：logo + 隊名色塊，中間圓形 `@` 分隔，非純文字

## 檔案結構

- `index.html` — 部署用主檔（與 cpbl-planner.html 相同，修改後需同步）
- `cpbl-planner.html` — 原始開發檔
- `games_data.json` — 賽程原始資料（JSON，僅備份用，不影響網頁運作）

## 更新賽程

若需更新賽程資料，重新呼叫 CPBL API 並替換 `index.html` 中的 `RAW_DATA` 變數即可。

## 部署

- GitHub Pages 從 `main` 分支的 `index.html` 部署
- 修改 `cpbl-planner.html` 後需複製到 `index.html` 再 push
