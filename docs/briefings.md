# 賽事簡報功能

2026-04-20 上線。已完賽場次卡片 footer 多一個「📋 簡報」pill，點擊展開 CPBL 官方的「賽事簡報」（連勝連敗紀錄、個人里程碑等）。

## 資料來源

CPBL API `POST /box/getlive`，回傳物件的 `CurtGameDetailJson.Briefing` 欄位是一段 HTML（含 `<p>`、`<span>`、`<br />` 等）。

需要的欄位：
- `GameSno`（int）：場次序號
- `Year`：'2026'
- `KindCode`：'A'（一軍例行賽）

範例（game 043，2026-04-17 樂天 vs 台鋼）：

```
艾速特 客場跨季4連勝(2025/08/26~)
陳文杰 達成生涯400安打(3局上)
陳文杰 單場9壘打數，個人生涯新高
樂天桃猿 3連敗(2026/03/29~)
林泓育 連續3場安打(2026/03/29~)
```

## 抓取流程

每場需要兩步 HTTP：
1. `GET /box?year=X&kindCode=A&gameSno=NNN` — 拿 session cookie + 表單隱藏 `__RequestVerificationToken`
2. `POST /box/getlive` — 送回 token + 其他 form 欄位（GameSno/KindCode/Year/PrevOrNext/PresentStatus）

## 快取策略

`data/briefings.json`，以 3 位零填 GameSno 為 key：

```json
{
  "001": "<p>...連勝連敗紀錄 HTML...</p>",
  "002": "...",
  ...
}
```

- 首次執行 `update-scores.ps1`：掃所有已完賽場次，全抓（約 45 場 × 2 請求 ≈ 30 秒）
- 後續每日執行：只抓「GameResult=0 且 sno 不在快取」的場次 → 通常每天 3 場內

## RAW_DATA 擴充

第 13 欄加 `GameSno`（3 位零填字串），用來 key BRIEFINGS：

```js
[日期, 時間, 客隊, 主隊, 球場, 客分, 主分, 勝投, 敗投, 救援, MVP, GameResult, GameSno]
```

## UI

`index.html` 有兩個標記區塊：

```js
// BRIEFINGS-START
const BRIEFINGS = {};
// BRIEFINGS-END
```

`update-scores.ps1` 用 marker 比對精準替換。HTML 嵌入完成後，卡片 render 邏輯會判斷：

```js
const hasBriefing = g.completed && g.sno && BRIEFINGS[g.sno];
```

有 briefing 才渲染 `<button class="btn-briefing">📋 簡報</button>`，點擊開啟 popover（架構類似天氣 popover，桌面彈窗、手機 bottom sheet）。

## 已知限制

**技術室人員前綴沒剝除**：CPBL 每個 briefing 開頭都有「技術室人員：XXX」那行，原本想剝掉但 PS 5.1 在中文原始碼環境下的 regex/string 行為詭異（詳見 [scoreupdate.md](scoreupdate.md#PowerShell-5.1-中文字面陷阱)），最後決定保留。資訊雖冗但不影響閱讀。

後續若要修，建議在前端 JS 端加 regex 過濾，而不是再試 PS 端。

## 相關檔案

- [scripts/update-scores.ps1](../scripts/update-scores.ps1) — 抓取 + 快取 + 注入 HTML
- [data/briefings.json](../data/briefings.json) — 快取檔
- [index.html](../index.html) — UI（搜尋 `BRIEFINGS-START` / `btn-briefing` / `briefing-popover`）
