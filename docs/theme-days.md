# 主題日功能規劃

在卡片上顯示各隊主場主題日資訊，讓使用者訂票時參考。

## 功能目標

- 未來主場場次若當日為主題日，卡片上顯示一個 badge（標題 + 對應色系）
- 點擊 badge 可跳轉到該隊官方主題日公告頁
- 六隊共用同一筆 JSON 資料來源，依「日期 + 主場隊」對應

## 資料來源（六隊官方公告）

| 球隊 | 官方公告頁 URL Pattern | 備用 FB / IG |
|------|----------------------|-------------|
| 中信兄弟 | `brothers.tw/POR0106_?BULLETIN_ID={id}`（列表：`POR0105_`） | [FB Brotherelephants](https://www.facebook.com/Brotherelephants/) |
| 樂天桃猿 | `monkeys.rakuten.com.tw/news_detail/{id}` | [FB RakutenMonkeys](https://www.facebook.com/RakutenMonkeys.official/) |
| 富邦悍將 | `fubonguardians.com/content/info/NewsDetail?id={id}` | [FB FubonGuardians](https://www.facebook.com/FubonGuardiansBaseballTeam/) / [IG](https://www.instagram.com/fubon_guardians_official/) |
| 味全龍 | `wdragons.com/{year}_theme_day/` ⭐ 唯一年度專頁 | [FB WC.DragonBaseball](https://www.facebook.com/WC.DragonBaseball/) |
| 統一獅 | `uni-lions.com.tw/news/only`（SPA 難爬，以 FB 為主） | [FB unilions](https://www.facebook.com/unilions/) / [IG](https://www.instagram.com/unilions_official/) |
| 台鋼雄鷹 | `tsghawks.com/news/`（搜尋未見主題日公告，以 FB 為主） | [FB TSGHAWKS](https://www.facebook.com/TSGHAWKS/) |

### 資料特性

- **沒有任何一隊提供 JSON API 或結構化資料**（無 JSON-LD、data attributes），全部是行銷圖文
- 每半季（約 3 月、6 月底）公告一次，一次含 7~10 檔主題日
- 中信／樂天／富邦單篇新聞頁可直接 fetch；統一／台鋼是 SPA，需靠 FB
- 味全龍是唯一有年度專頁（`/2026_theme_day/`），可持續更新

## 資料結構

`data/theme_days.json`

```json
{
  "2026-04-03": [
    {
      "home_team": "富邦悍將",
      "title": "BLUE POWER",
      "subtitle": "主場開幕戰",
      "source_url": "https://www.fubonguardians.com/content/info/NewsDetail?id=676"
    }
  ],
  "2026-04-25": [
    {
      "home_team": "中信兄弟",
      "title": "Snoopy & His Siblings",
      "subtitle": "Peanuts 聯名主題日",
      "source_url": "https://www.brothers.tw/POR0106_?BULLETIN_ID=P18U7B3Y"
    }
  ]
}
```

- Key 為日期字串（`YYYY-MM-DD`），value 為陣列（同日可能多隊有主題日，雖少見）
- `home_team` 必須對應 RAW_DATA 中的主隊名稱（中信兄弟、樂天桃猿、富邦悍將、味全龍、統一7-ELEVEn獅、台鋼雄鷹）
- `subtitle` 可選，僅在需要補充時使用
- `source_url` 指向官方公告頁，點擊 badge 開新分頁

## 資料流

```
頁面載入 → fetch data/theme_days.json（與 RAW_DATA 並行）
         → render() 時，對每個未來非延賽場次查表
              ├─ 以 game.date + game.home_team 查 JSON
              └─ 有對應則在卡片上注入 badge
```

- 純前端查表，無 API 呼叫
- 延賽／過去場次不顯示 badge（避免視覺雜訊）

## UI 整合

插入位置：`card-body` 內，對戰區與 footer 之間。樣式對齊現有 `.btn-ticket`。

```
┌─────────────────────────────────┐
│ 18:35      ◉ 洲際棒球場          │ <- 頂部欄
├─────────────────────────────────┤
│   [中信]  VS  [樂天]             │ <- 對戰區
│                                 │
│  [ 🎉 Snoopy 聯名 · Peanuts ]    │ <- badge（inline pill，置中）
│                                 │
├─────────────────────────────────┤
│ [週六]        [購票] [高鐵]      │ <- footer
└─────────────────────────────────┘
```

- Badge 樣式：單色奶茶底 `#FDF6EE` + 赤陶紅字 `#C2573A`，圓角 14px pill，與「購票」「高鐵」按鈕同款
- 顯示條件：未來場次 + 非延賽 + JSON 有對應
- 「全部」「已結束」模式下過去主題日不顯示（已經結束、沒有訂票價值）
- 卡片高度一致：`.card-grid` 用 `align-items: stretch`，`.game-card` 用 flex column + `.card-body { flex: 1 }`，讓有無 badge 的同排卡片齊高

## 更新流程

每半季開賽前（約 3 月中、6 月底）執行一次：

1. 打開六隊官方公告頁（上表）或官方 FB
2. 請 Claude 讀取、解析並更新 `data/theme_days.json`
3. Review diff → commit → push

**不做自動化爬取**，理由：

- 一年只跑 2 次，排程 ROI 低
- 六隊格式都不同，寫 6 個 parser 維護成本高
- 資料需人工判讀（挑代表性名稱、避免行銷贅詞）

## 資料來源優先順序

1. **官網單篇新聞頁**（中信、樂天、富邦、味全）— 最可靠，URL 穩定
2. **官方 FB 貼文**（統一、台鋼）— 官網 SPA 難爬時的備案
3. ~~新聞媒體彙整（NOWnews、LINE TODAY）~~ — 二手資訊，不採用

## 注意事項

- 主題日日期有時為「連續三天」，需展開為 3 筆 entry（每天一筆）
- 大巨蛋舉辦的主場賽事也算主場球隊的主題日（例：統一獅 6/5-6/7 在大巨蛋）
- 一日若有雙主題（不同隊都剛好主題日）實務上經常發生（上半季有 25+ 個日期同時多隊），JSON 結構允許陣列
- 球團臨時變更（延賽順延、活動取消）不頻繁，發現時手動修正 JSON
- **新聞報導日期若與 RAW_DATA 不對應必須移除**：不能編造或猜測（例：原 NOWnews 記載台鋼 5/30-6/1 覺察多巴胺，實際這三天台鋼都是客場，已移除等候後續確認）

## 實作紀錄

### 2026-04-20 首次上線

**資料**：`data/theme_days.json`，2026 上半季 107 筆 entry（47 個日期），涵蓋六隊全部已公告主題日，全部由官網/官方 FB 取得。

**UI**：
- Badge 採用 `.btn-ticket` 同款 pill 樣式（背景 `#FDF6EE`、邊框 `#E8D5B8`、字色 `#C2573A`、12px／600），hover 反白為赤陶紅
- 格式：`🎉 主題名 · 副標`（單行 inline-block，長度自動折行）
- 位置：卡片 `card-body` 內，對戰區與 footer 之間（`.theme-day-wrap` 置中）
- 同時修正 `.card-grid` 加 `align-items: stretch` + `.game-card` 改 `display: flex; flex-direction: column` + `.card-body { flex: 1 }`，讓有無 badge 的卡片在同一排高度一致

**驗證**：Headless Edge 實測 2026-04-20 之後 75 個未來非延賽場次正確顯示 badge，同排卡片 footer 對齊在同一條水平線。

## 待辦

- [x] 建立 `data/theme_days.json` 與 2026 上半季資料
- [x] 在 `cpbl-planner.html` / `index.html` 加入 fetch 與 render 邏輯
- [x] 設計 badge CSS（奶茶棕配色，與整體 Snoopy Museum 風格一致）
- [x] 修正卡片高度不齊（badge 有無造成視覺不整齊）
- [ ] 台鋼「覺察多巴胺」確認正確日期後補回
- [ ] 找到統一獅、台鋼雄鷹更精確的單篇公告連結（目前指向 FB 主頁）
- [ ] 2026 下半季公告出爐時（約 6 月底）更新 JSON
