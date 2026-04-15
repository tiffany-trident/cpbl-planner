# UI 設計風格討論摘要

記錄 CPBL 2026 進場倒數網站 UI 改版方向與決策。

## 核心設計原則

### Snoopy Museum 風格的「真義」
參考 Snoopy Museum Tokyo 風格時，**重點是 Snoopy，不是 Museum**。

- ✅ 要：卡通、漫畫、活潑、溫暖、手感插畫、親切、帶點童趣
- ❌ 不要：博物館典雅、襯線體、文青冷靜、抽象幾何裝飾

過去錯把重點放在「博物館」的典雅感，推薦 Noto Serif TC 和冷靜排版，是偏離方向的。

## 字體決策

### 繁體中文字體相容性重要警告

**日文字體（Hachi Maru Pop、Kosugi Maru、Klee One 等）不含繁體中文字形。**

- 日文「数」（U+6570, shinjitai）≠ 繁中「數」（U+6578）
- 若強用日文字體顯示繁中，瀏覽器會 per-character fallback 到 Noto Sans TC
- 結果：有些字看起來像在套這個字體，其實都是 fallback，會造成字形不一致或根本沒生效

### 結論：主要字體選擇

| 用途 | 字體 | 理由 |
|------|------|------|
| **中文標題** | **jf 粉圓體（open-huninn）** | Taiwan JustFont 基於 Kosugi Maru 改造的繁中版本，SIL OFL 免費商用，真正的 Snoopy 卡通可愛感 |
| 英文標題裝飾 | Hachi Maru Pop / Kosugi Maru | 日文字體不能用在繁中，但可用於英文（eyebrow、年份、比分數字、背號等裝飾文字） |
| 不推薦 | Noto Serif TC | 襯線典雅、博物館文青感，偏離 Snoopy 方向 |
| 不推薦 | LXGW WenKai TC | 實際是傳統「楷書」字體（類似小學課本字），不是卡通手寫字 |

### jf 粉圓體 CDN 載入方式

```css
@font-face {
  font-family: 'jf-openhuninn';
  src: url('https://cdn.jsdelivr.net/gh/marsnow/open-huninn-font@1.1/font/jf-openhuninn.woff2') format('woff2'),
       url('https://cdn.jsdelivr.net/gh/marsnow/open-huninn-font@1.1/font/jf-openhuninn.woff') format('woff');
  font-display: swap;
}
```

## 圖示與插畫方向

### 彩色插畫 > 線條圖示
設計方向選擇「彩色插畫」風，不是單色線條圖示。

### 推薦資源（依優先順序）

| 資源 | 授權 | 用途 |
|------|------|------|
| **Twemoji** | CC-BY 4.0 | 取代原生 emoji，彩色卡通 SVG，跨平台一致，CDN：`https://cdn.jsdelivr.net/gh/jdecked/twemoji@latest/assets/svg/` |
| Flaticon Stickers | 需標註來源 | 更精緻的棒球貼紙風格 |
| OpenMoji | CC-BY-SA 4.0 | 手繪感更強的 emoji 替代 |

### 關於 Tabler Icons
- MIT 授權、免費商用、無需標註
- **線條風格，適合做 UI 輔助圖示（如 filter、search、arrow）**
- **不適合做主要視覺**（Hero、裝飾）— 風格太冷、不夠 Snoopy
- 已下載 94 個到 `icon-preview/icons/` 作為備用

## Hero 區改版方向

### 現行舊版問題
```
🏏 [emoji]    中華職棒一軍例行賽
               進場倒數                    [emoji] ⚾
          在最好的日子，走進最好的球場
               —— ◆ ——
```

**問題清單：**
1. `🏏⚾` 原生 emoji 跨平台渲染不一致（Windows/Mac/Android 風格各異）
2. 兩個 emoji 用 `position: absolute` 飄在左右兩側，孤單、不融入排版
3. 資訊密度低，大 padding 區只有抒情短語
4. 缺少「棒球感」視覺錨點

### 採用方案：Hero B — 加入動態資訊

```
         中華職棒一軍例行賽 · 2026
              進場倒數
    [⚾] 今日 3 場  [📅] 剩餘 240 場  [🔥] 賽季進行中
              ● —— ◆ —— ●
```

改動重點：
- Eyebrow 加上年份 `· 2026`
- 主標「進場倒數」用 **jf 粉圓體**，字級 52-56px，字距加寬
- 新增膠囊狀資訊列：今日場次 / 剩餘場次 / 賽季狀態
- 所有 emoji 換成 **Twemoji 彩色 SVG**，跨平台一致
- 背景 `#FFF9F0`、邊框 `#F0DFB8`、數字用赤陶紅粗體
- 下方裝飾改為星星🏆星星（Twemoji）

### 未採用：Hero C — 倒數計時器
完整動態倒數「距開打 09:45:22」+ 下一場比賽卡片，改動較大，暫緩。

## 色彩系統（沿用現有）

| 角色 | 色碼 | 用途 |
|------|------|------|
| 背景淡米 | `#FDFCFA` | 頁面背景 |
| 白底 | `#FFF` | 卡片、區塊 |
| 主文字 | `#4A3728` | 內文 |
| 標題深棕 | `#3D3122` | 大標 |
| 重點赤陶紅 | `#C2573A` | CTA、數字強調 |
| 淡奶茶 | `#FDF6EE` | 膠囊背景、hover |
| 高鐵綠 | `#2B8A8A` | 高鐵按鈕 |
| 未來綠 | `#4A8B5C` | 狀態提示 |

## 未來的 Snoopy 化延伸建議

字體和圖示改完後，可繼續卡通化的項目：

| 目前 | Snoopy 化建議 |
|------|--------------|
| 抒情短語「在最好的日子…」 | 輕鬆口吻如「來看球吧！⚾」 |
| `● —— ◆ —— ●` 幾何裝飾 | 手繪波浪線、小星星、小閃電 |
| Section 標題 Noto Serif TC | 改成 jf 粉圓體 + 可愛小圖示 |
| 精緻直線陰影 | 柔軟卡通 drop shadow |

## 預覽檔案

- `icon-preview/preview.html` — 字體試穿、Hero 變體對照、Twemoji 插畫、Tabler Icons 網格
- `icon-preview/icons/` — 94 個 Tabler Icons SVG

## 實作摘要（2026-04-15 commit `478a038`）

方案 ① jf 粉圓體 + Hero B 動態資訊列已正式套用到 `cpbl-planner.html` 和 `index.html`。

### 決策範圍
| 項目 | 決策 |
|------|------|
| jf 粉圓體套用範圍 | **只改 Hero 區 + Section 標題**（各隊戰績／賽程總覽），其他維持 Noto Sans TC，內文保持可讀性優先 |
| Hero 三格資訊列 | **動態計算**（讀 RAW_DATA）：今日場次／剩餘場次／賽季狀態 |
| 分隔線裝飾 | **保留原幾何風** `● —— ◆ —— ●`，不改手繪風 |
| Emoji 統一 Twemoji | **暫不動**，待試 Flaticon Stickers 後再決定 |

### 技術細節
- `@font-face` 載入 jf-openhuninn（CDN：`cdn.jsdelivr.net/gh/marsnow/open-huninn-font@1.1`），已驗證回 200
- Hero h1：42px/700 Noto Serif → **56px/500 粉圓體 + 字距 4px**
- Section 標題：18px/700 Noto Serif → **20px/500 粉圓體 + 字距 1.5px**（粉圓體在 700 會略糊）
- `buildHeroInfo()` 於 `loadData()` 呼叫，計算邏輯：
  - 今日場次 = `date === todayStr && !postponed`
  - 剩餘場次 = `isFuture && !postponed`
  - 賽季狀態 = 未開幕／熱烈進行中／已結束（依 completed/future 狀態判斷）
- Hero `<p>` 抒情短語移除，改為膠囊資訊列 `.hero-info`

### 未套用的延伸項目（等試完 Flaticon 再評估）
- [ ] 全站 emoji 改 Twemoji / Flaticon Stickers
- [ ] Section 標題分隔線改手繪風
- [ ] 新文案方向（抒情 → 親切口吻）
- [x] `.filter-card-title`、`.nav-title`、頁尾標題是否一起換粉圓體 → 於 e95258b 一起換

## 實作摘要（2026-04-15 commit `e95258b`）

Hero 圖示、Section 配圖、字體一致性補刀。

### 決策範圍

| 項目 | 決策 |
|------|------|
| Hero 左圖示 | 🏏（板球）→ **自繪 SVG 棒球手套**（赤陶紅 `#C2573A` 主色） |
| Hero 右圖示 | 原生 ⚾ → **Fluent 3D 棒球 PNG**（跨平台一致） |
| Hero 裝飾線 | **保留** `● —— ◆ —— ●`，曾試 `⭐ 〰 ⚾ 〰 ⭐` 被否決（太突兀） |
| 各隊戰績標題 | 加 **Fluent 3D 獎盃** icon |
| 賽程總覽標題 | 加 **自繪 SVG 棒球場** icon（菱形 + 四壘包 + 外野扇形 + 投手丘） |
| 字體一致性 | `.nav-title` / `.filter-card-title` / `.footer` 全換 jf 粉圓體 weight 500 |

### Emoji 與棒球主題的幾個關鍵認知

- **🏏 是板球（cricket），不是棒球**。Unicode **沒有獨立的「棒球球棒」emoji**，所以 Microsoft Fluent / Google Noto / OpenMoji 全家都只有 `Cricket game` 板球圖組。要球棒只能自繪。
- **Fluent `Stadium` 是通用綜合體育場**（圓頂/碗狀），不是棒球場菱形。要棒球場也只能自繪。
- Fluent Emoji MIT 授權、OpenMoji CC-BY-SA、Twemoji CC-BY — 外部圖庫有多種選擇。
- Hero 兩側「飄浮裝飾」本來沒功能意義，但 emoji 跨平台渲染不一致是問題，換成 SVG/PNG 就統一了。

### 技術細節

- `.snoopy-float` 原先依賴 emoji 行高自然定位，改 SVG/img 後需加 `top: 50%; transform: translateY(-50%)` 明確置中
- `.section-icon` 基礎 22px / 手機 18px；棒球場 SVG 細節多，用 `svg.section-icon` 選擇器放大到 28px / 22px
- Fluent PNG CDN：`https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/{name}/3D/{slug}_3d.png`（空格要 `%20`）
- 棒球場 SVG 配色：外野 `#8FC271`、內野土 `#D4A574`、投手丘 `#C2573A`（網站赤陶紅）、壘包白
- 棒球手套 SVG 已在 hero-icons-preview.html 的 方案 B 中驗證過

### 工作流程收穫

- 建立 `icon-preview/hero-icons-preview.html` 對照頁，把多個候選方案用**完整 Hero 區塊**（含實際 `.hero-info` class 結構）並排顯示，讓使用者視覺比較後再決定——比描述文字有效很多
- 對照頁的 hero-info markup **必須複用真實網站的 class**，不然分隔點會繼承 body 色變黑，偏離真實效果
- 自繪 SVG 反覆迭代：第一版球棒形狀粗糙（兩段拼接），第二版才用單一 path 做出標準棒球球棒輪廓（圓頂→桶身→漸細→握把→knob）

## 開發教訓

### 每次修改 CSS/字體/視覺後，必須自行驗證
- 寫完 CSS 要檢查特異性衝突（尤其 `.hero-preview h1` 這種組合選擇器會蓋過單純 class）
- 載入第三方字體要驗證 CDN URL 有效（曾犯 404 錯誤、`@font-face font-family` 名稱不符等）
- 日文字體用於中文前要確認字形覆蓋（數 vs 数 等差異）
- 不可只靠推理假設「應該會生效」就交差

## Bug 修正紀錄

### 2026-04-15：Hero「今日場次」少算一場（時區 bug）

**症狀**：今日（2026-04-15）實際有 3 場比賽，但 Hero 資訊列顯示「今日 2 場」。卡片上的「今日」橘色 badge 也錯標到前一天的場次。

**原因**：`loadData()` 與 `buildHeroInfo()` 都用 `today.toISOString().slice(0, 10)` 取得「今日字串」。`toISOString()` 會把時間轉成 UTC：
- 台灣 UTC+8 的本地午夜 `2026-04-15 00:00 +08:00`
- 對應 UTC 時間是 `2026-04-14 16:00`
- `toISOString().slice(0,10)` → `"2026-04-14"`

於是 `todayStr` 永遠比實際本地日期早一天，比對 `g.date === todayStr` 自然抓錯場次。

**修正**：改用本地時間自行組字串，避開 UTC 轉換：
```js
const todayStr = `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
```

同步修正 `index.html` 與 `cpbl-planner.html` 的兩處（loadData、buildHeroInfo）。

**教訓**：JavaScript `Date.toISOString()` 一律輸出 UTC，任何「本地日期字串」需求都不能直接用它 slice。處理日期字串時，先想清楚要的是 UTC 還是本地時區。

## 實作摘要（2026-04-15 commit `92844c4`）

新增 favicon — 瀏覽器分頁圖示。

### 決策範圍

| 項目 | 決策 |
|------|------|
| 載入方式 | **inline SVG data URI**，不另外放檔案，避免 404 與快取問題 |
| 主視覺 | 赤陶紅 `#C2573A` 圓底 + 米白 `#FFF8F0` 棒球 + 赤陶紅縫線與縫針 |
| iOS 主畫面版本 | 另加 `apple-touch-icon`（圓角方形底 + 棒球，無縫針細節） |
| 檔案範圍 | 同步 `index.html` 與 `cpbl-planner.html` |

### 為什麼用 inline SVG data URI

- 不需額外 `favicon.ico` 或 PNG 檔案，減少部署負擔
- SVG 原生可縮放，分頁（16/32px）與書籤（任意大小）都清楚
- data URI 直接嵌在 HTML 裡，不會有獨立快取與跨網域問題
- 現代瀏覽器全支援 `<link rel="icon" type="image/svg+xml">`

### 技術細節

- `<link rel="icon" type="image/svg+xml">` 給桌面瀏覽器分頁
- `<link rel="apple-touch-icon">` 給 iOS Safari「加到主畫面」
- SVG viewBox `0 0 64 64`，分頁版縮成圓形（外圈圓）、iOS 版用 rounded rect（`rx='14'`）符合 app icon 慣例
- 縫線用兩條 `Q` quadratic bezier 弧，縫針用 12 條小斜線模擬棒球手縫細節
- 所有 `#` 在 data URI 中需 URL encode 為 `%23`

### 專有名詞備註

瀏覽器分頁上那個圖示正式名稱是 **favicon**（favorites icon，IE5 引進）。相關變體：

- `rel="icon"` — 一般 favicon（分頁、書籤、歷史）
- `rel="apple-touch-icon"` — iOS/iPadOS 加到主畫面圖示
- PWA `manifest.json` 的 `icons` — Android 主畫面與 splash screen

### 開發教訓

- GitHub Pages 有強烈快取，favicon 比 HTML 頁面本身更頑固，更新後可能需要關掉分頁重開才會換新圖
