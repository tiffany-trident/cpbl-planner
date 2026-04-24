# 資料來源與格式

## CPBL 官方 API

- 端點：`POST https://cpbl.com.tw/schedule/getgamedatas`
- 需要 `RequestVerificationToken` 才能呼叫
- 取得 token 流程：
  1. 先 GET `https://cpbl.com.tw/schedule`
  2. 從回應 cookie 與頁面內嵌抽出 token
  3. 帶 token 再呼叫 `getgamedatas`

## 2026 球季基本資料

- 總場次：**364 場**（含延賽）
- 球隊：**6 隊**（中信兄弟、樂天桃猿、富邦悍將、統一 7-ELEVEn 獅、味全龍、台鋼雄鷹）
- 球場：**11 座**（大巨蛋、天母、新莊、樂天桃園、洲際、嘉義市、亞太主、澄清湖、斗六、花蓮、台東）
- 賽季期間：2026-03-28 ~ 2026-09-28

## 資料內嵌

- 所有場次資料以 `RAW_DATA` JavaScript 常數內嵌在 `index.html` / `cpbl-planner.html`
- 各隊 logo 從 `cpbl.com.tw` 遠端引用
- 戰績區顯示資料來源註記：`https://cpbl.com.tw/standings/season`

## RAW_DATA 格式

每場比賽一筆陣列，欄位順序固定：

```
[日期, 時間, 客隊, 主隊, 球場, 客分, 主分, 勝投, 敗投, 救援, MVP, GameResult, GameSno]
```

### 特殊欄位

| 欄位 | 值 | 意義 |
|------|-----|------|
| `GameResult` | `"0"` | 已完賽 |
| `GameResult` | `"1"` | 延賽取消 |
| `GameResult` | `""`（空字串） | 未賽 |
| `GameSno` | `"001"` ~ `"364"`（3 位零填） | 場次編號，用來對應 `const BRIEFINGS` 賽事記錄 |

## 相關自動更新

- 抓取腳本：`scripts/fetch-scores.sh`、`scripts/update-scores.ps1`
- 排程：現行方案為 Windows Task Scheduler 本機執行，詳見 [scoreupdate.md](scoreupdate.md)
