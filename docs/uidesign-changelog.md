# UI 實作紀錄與教訓

CPBL 2026 進場倒數網站的 commit 實作摘要、Bug 修正、開發教訓。設計原則見 [uidesign.md](uidesign.md)。

## Commit 實作紀錄

### 2026-04-17 — 天氣改用 ECMWF IFS 模型提升準確度

使用者反映天氣不夠精確。Open-Meteo 預設 `best_match` 為多模型聚合，改指定 `models=ecmwf_ifs025`（歐洲中期天氣預報中心 IFS 模型，公認全球最準）。

| 項目 | 決策 |
|------|------|
| 模型選擇 | ECMWF IFS 0.25°（`ecmwf_ifs025`） |
| 試過 JMA | 日本氣象廳 `jma_seamless` 對台灣可能更貼近，但不回傳 `precipitation_probability`（全 null），否決 |
| 快取處理 | localStorage key `weather_` → `weather_v2_`，舊模型資料自動失效 |
| 改動範圍 | `cpbl-planner.html` + `index.html` 僅改 fetch URL 和 localStorage key |

教訓：
- 換 Open-Meteo 模型前必須驗證該模型是否支援所有需要的欄位，尤其 `precipitation_probability` 並非每個模型都提供
- 模型列表參考：https://open-meteo.com/en/docs（Weather models 段落）
- 若 ECMWF 仍不夠準，下一步可評估切換至 CWA 中央氣象署 API（鄉鎮級預報，台灣最準，但需註冊 API key 且解析邏輯要重寫），評估已記於 [weather.md](weather.md)

### 2026-04-15 `478a038` — jf 粉圓體 + Hero B 動態資訊列

方案 ① jf 粉圓體 + Hero B 動態資訊列正式套用到 `cpbl-planner.html` 和 `index.html`。

| 項目 | 決策 |
|------|------|
| jf 粉圓體套用範圍 | 只改 Hero + Section 標題（戰績/賽程），其他維持 Noto Sans TC |
| Hero 三格資訊列 | 動態計算（讀 RAW_DATA）：今日場次／剩餘場次／賽季狀態 |
| 分隔線裝飾 | 保留原幾何風 `● —— ◆ —— ●` |
| Emoji 統一 Twemoji | 暫不動，待試 Flaticon Stickers 後再決定 |

技術細節：
- `@font-face` 載入 jf-openhuninn，CDN `cdn.jsdelivr.net/gh/marsnow/open-huninn-font@1.1` 已驗證回 200
- Hero h1：42px/700 Noto Serif → 56px/500 粉圓體 + 字距 4px
- Section 標題：18px/700 Noto Serif → 20px/500 粉圓體 + 字距 1.5px（粉圓體在 700 會略糊）
- `buildHeroInfo()` 於 `loadData()` 呼叫：
  - 今日場次 = `date === todayStr && !postponed`
  - 剩餘場次 = `isFuture && !postponed`
  - 賽季狀態 = 未開幕／熱烈進行中／已結束
- Hero `<p>` 抒情短語移除，改為膠囊資訊列 `.hero-info`

### 2026-04-15 `e95258b` — Hero 圖示卡通化、字體一致性

| 項目 | 決策 |
|------|------|
| Hero 左圖示 | 🏏（板球）→ 自繪 SVG 棒球手套（赤陶紅主色） |
| Hero 右圖示 | 原生 ⚾ → Fluent 3D 棒球 PNG |
| Hero 裝飾線 | 保留 `● —— ◆ —— ●`（試過 `⭐ 〰 ⚾ 〰 ⭐` 被否決） |
| 各隊戰績標題 | 加 Fluent 3D 獎盃 icon |
| 賽程總覽標題 | 加自繪 SVG 棒球場 icon |
| 字體一致性 | `.nav-title` / `.filter-card-title` / `.footer` 全換 jf 粉圓體 weight 500 |

工作流程收穫：
- 建立 `icon-preview/hero-icons-preview.html` 對照頁，用**完整 Hero 區塊**（含實際 `.hero-info` class 結構）並排顯示，比文字描述有效
- 對照頁 markup **必須複用真實網站的 class**，不然分隔點會繼承 body 色變黑偏離真實效果
- 自繪 SVG 反覆迭代：第一版球棒兩段拼接粗糙，第二版才用單一 path 做出標準棒球球棒輪廓（圓頂→桶身→漸細→握把→knob）

### 2026-04-15 `92844c4` — 新增 favicon

| 項目 | 決策 |
|------|------|
| 載入方式 | inline SVG data URI，不另放檔案避免 404 與快取問題 |
| 主視覺 | 赤陶紅圓底 + 米白棒球 + 赤陶紅縫線與縫針 |
| iOS 版本 | `apple-touch-icon` 圓角方形底 + 棒球（無縫針細節） |
| 檔案範圍 | 同步 `index.html` 與 `cpbl-planner.html` |

為什麼用 inline SVG data URI：
- 不需額外 `favicon.ico` 或 PNG，減少部署負擔
- SVG 原生可縮放，分頁（16/32px）與書籤（任意大小）都清楚
- data URI 直接嵌在 HTML 裡，不會有獨立快取與跨網域問題

專有名詞：瀏覽器分頁圖示正式名稱是 **favicon**（favorites icon，IE5 引進）
- `rel="icon"` — 一般 favicon（分頁、書籤、歷史）
- `rel="apple-touch-icon"` — iOS/iPadOS 加到主畫面
- PWA `manifest.json` 的 `icons` — Android 主畫面與 splash screen

### 2026-04-15 `f7b0cf0` — Nav 置頂 + 手機版 Hero 圖示排版修正

| 項目 | 決策 |
|------|------|
| Nav 置頂 | `position: sticky; top: 0; z-index: 100`，滾動時固定頂部，兼當「返回頂部」功能 |
| 手機版 Hero 圖示 | 取消 `position: absolute`，改用 `flex-wrap` + `order: 2` 讓手套與棒球排到文字下方並排置中 |
| 手機版 hero-deco | 隱藏 `● —— ◆ —— ●` 裝飾線，兩個 icon 並排已有裝飾效果 |
| 手機版 icon 尺寸 | 手套 36px、棒球 32px（桌面版不變） |

技術細節：
- `.hero` 手機版加 `flex-wrap: wrap; gap: 12px`
- `.hero-content { width: 100%; }` 讓文字獨佔第一行
- `.snoopy-float { position: static; transform: none; order: 2; }` 兩個 icon 都排到第二行
- `justify-content: center`（繼承桌面版）讓第二行 icon 自動置中
- 桌面版不受影響：`flex-wrap`、`width`、`order` 都只在 `@media (max-width: 768px)` 內

迭代過程：
1. 第一版直接 `display: none` 隱藏 → Tiffany 反饋想保留圖示
2. 第二版改 `position: static` 但沒加 `flex-wrap` 和 `width: 100%` → icon 跑到 info pill 旁邊
3. 第三版加 `flex-wrap` + `hero-content width: 100%` 但沒加 `order` → HTML 順序導致手套在文字上方、棒球在下方，各自獨佔一行
4. 第四版加 `order: 2` → 兩個 icon 都排到文字下方同一行，正確

### 2026-04-16 `1905310` — 新增球場天氣預報功能

| 項目 | 決策 |
|------|------|
| 資料來源 | Open-Meteo 免費 API（不需 key、支援 CORS） |
| 觸發時機 | 頁面載入後非同步自動 fetch，不需排程 |
| 快取策略 | localStorage 每球場獨立存，TTL 3 小時 |
| 顯示範圍 | 未來 7 天內、非延賽的場次 |
| 72 小時內 | 比賽開打那小時的逐時預報：`18時 ☀️ 28° · 10%💧` |
| 3~7 天 | 當日白天概況（10:00-21:00 高低溫 + 最大降雨率）：`全日 ⛅ 22-28° · 40%💧` |
| 超過 7 天 / 已完賽 / 延賽 | 不顯示 |
| 卡片位置 | card-top 列，時間與球場之間 |
| 樣式 | 12px 暖米底 `#FFF9F0` 圓角 pill，手機版 11px |
| 降雨率警示 | ≥ 50% 轉紅色 `#C25B5B` |
| 載入中 | `⏳ 天氣載入中…` 脈衝動畫 |
| API 失敗 | 靜默跳過，不影響原功能 |
| 時間標示 | hourly 顯示「18時」、daily 顯示「全日」，讓使用者辨別預報時段 |

技術細節：
- `STADIUM_COORDS`：10 球場經緯度對應
- `WMO_WEATHER_MAP`：WMO 天氣代碼 → emoji + 中文（晴/多雲/霧/毛毛雨/雨/陣雨/雷雨）
- `loadWeather()` 於 `loadData()` 最後呼叫，先 render 載入動畫 → fetch → 再 render 實際天氣
- `fetchWeatherForStadiums()` 用 `Promise.allSettled()` 平行 fetch + `AbortController` 10 秒逾時
- localStorage 滿了只用記憶體快取，`try/catch` 靜默處理
- `forecast_days=7` 實際涵蓋今天 + 未來 6 天（API 行為），第 7 天場次可能無資料但不報錯

## Bug 修正紀錄

### 2026-04-15：Hero「今日場次」少算一場（時區 bug）

**症狀**：今日（2026-04-15）實際有 3 場比賽，但 Hero 資訊列顯示「今日 2 場」。卡片「今日」橘色 badge 也錯標到前一天場次。

**原因**：`loadData()` 與 `buildHeroInfo()` 都用 `today.toISOString().slice(0, 10)` 取得今日字串。`toISOString()` 會轉成 UTC：
- 台灣 UTC+8 本地午夜 `2026-04-15 00:00 +08:00`
- 對應 UTC `2026-04-14 16:00`
- `toISOString().slice(0,10)` → `"2026-04-14"`

`todayStr` 永遠比實際本地日期早一天，比對 `g.date === todayStr` 自然抓錯場次。

**修正**：改用本地時間自行組字串，避開 UTC 轉換：
```js
const todayStr = `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
```

同步修正 `index.html` 與 `cpbl-planner.html` 的兩處（loadData、buildHeroInfo）。

**教訓**：JavaScript `Date.toISOString()` 一律輸出 UTC，任何「本地日期字串」需求都不能直接用它 slice。處理日期字串前先想清楚要的是 UTC 還是本地時區。

## 開發教訓

### 修改 CSS/字體/視覺後必須自行驗證

- CSS 特異性衝突：組合選擇器（如 `.hero-preview h1`）會蓋過單純 class，改完要實際檢查
- 載入第三方字體要驗證 CDN URL 有效（曾犯 404 錯誤、`@font-face font-family` 名稱不符等）
- 日文字體用於中文前要確認字形覆蓋（數 vs 数 等差異）
- 不可只靠推理假設「應該會生效」就交差

### GitHub Pages 快取

- Favicon 比 HTML 頁面本身更頑固，更新後可能需要關掉分頁重開才換新圖
- 一般頁面更新後使用者可能需 Ctrl+Shift+R 硬重整才會看到最新資料
