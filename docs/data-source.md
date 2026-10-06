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
| `GameResult` | `"0"` | 已完賽（含補賽、續賽的最終紀錄） |
| `GameResult` | `"1"` | 延賽取消（整場作廢，擇日重打） |
| `GameResult` | `"2"` | **保留比賽**（已開打但中止，擇日從中止點續打） |
| `GameResult` | `""`（空字串） | 未賽 |
| `GameSno` | `"001"` ~ `"364"`（3 位零填） | 例行賽場次編號，用來對應 `const BRIEFINGS` 賽事記錄 |
| `GameSno` | `"E001"`、`"C001"`… | **季後賽**：`E` = 一軍季後挑戰賽、`C` = 一軍總冠軍賽（台灣大賽）。API 的 GameSno 每個賽別都從 1 起算，加前綴避免與例行賽撞號；收藏、打卡、`BRIEFINGS`、`data/box/E001.json` 都用這個 key |

### 季後賽（2026-10-06 起）

- 抓取：`update-scores.ps1` 在例行賽（`KindCode=A`）之後再打兩次 `getgamedatas`，參數 `calendar=YYYY/01/01&location=&kindCode=E|C&teamNo=`（小寫，與官網 /schedule 頁相同）。回空陣列 = 尚未公布
- 官方會預先列出「必要時才打」的場次與已確定的對戰隊伍（2026 挑戰賽 4 場一次全列）
- Box / 賽事記錄：`/box?kindCode=E&gameSno=001`，存成 `data/box/E001.json`
- 前端 `loadData()` 由 sno 前綴推出 `kind` / `isPost` / `gameNo`；`regularGames()` 只取例行賽，戰績、半季、季後賽席次、例行賽季末判斷都只用它
- 賽制：全年勝率最高的半季冠軍直接進台灣大賽；另一半季冠軍（先取 1 勝、主場 3 場，1-1-2）對外卡打四戰三勝挑戰賽；台灣大賽七戰四勝。同隊包辦兩冠時改由全年第 2、3 名打五戰三勝（[維基百科](https://zh.wikipedia.org/zh-tw/%E4%B8%AD%E8%8F%AF%E8%81%B7%E6%A3%92%E5%AD%A3%E5%BE%8C%E6%8C%91%E6%88%B0%E8%B3%BD)，已對照 2025 API 實際賽程）

### 延賽 / 補賽 / 保留比賽 / 續賽

同一個 `GameSno` 可能出現多筆，代表同一場比賽的不同階段：

| 情境 | API 資料樣態 |
|------|-------------|
| 延賽（`gr=1`） | 原日期留一筆 `gr=1`（0:0、無勝投）；補賽另開同 sno 新日期一筆。整場重打，比分不承接 |
| 保留比賽（`gr=2`） | 中止當天留一筆 `gr=2`，帶**中止時比分**與 `ReserveDate`（續賽日期）；續賽日另開同 sno 一筆 `gr=0`，其 `GameDateTimeS` 仍是**原本開打那天**、`GameDateTimeE` 才是續賽日 → 官方視為「同一場跨兩天」 |

2026 球季實例（已向 API 驗證）：

- sno 150：6/07 洲際樂天 2:0 中信打到 17:49 中止保留 → 6/28 續賽完成，終局 2:0（比賽時間 02:22 含續打）
- sno 151：6/09 新莊味全對富邦**延賽**（`gr=1`）→ 改 6/25 補賽，打到 19:41 又**中止保留**（`gr=2`，當時 1:4）→ 6/28 續賽完成，終局 1:4

程式端對應（`loadData()`）：`postponed = gr==='1'`、`suspended = gr==='2'`、`isMakeup`（同 sno 有 `gr=1`）、`isResumed`（`gr=0` 且同 sno 有較早的 `gr=2`）。統計列「延賽」把 `gr=1` 與 `gr=2` 視為同一類（原定時間沒打完），並排除同 sno 已完賽者、以 sno 去重。

## 中職相關新聞來源

- 來源：自由時報體育 RSS `https://news.ltn.com.tw/rss/sports.xml`（純連結聚合，只存標題/來源/時間/連結）
- 抓取腳本：`scripts/fetch-news.ps1` → `data/news.json`
- 版權原則與過濾邏輯見 [news.md](news.md)

## 相關自動更新

- 抓取腳本：`scripts/fetch-scores.sh`、`scripts/update-scores.ps1`、`scripts/fetch-news.ps1`
- 排程：現行方案為 Windows Task Scheduler 本機執行，`update-scores.bat` 一併呼叫比分與新聞抓取，詳見 [scoreupdate.md](scoreupdate.md)
