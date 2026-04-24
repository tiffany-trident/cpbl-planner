# UI 設計風格指南

CPBL 2026 進場倒數網站的設計決策與風格系統。實作紀錄與 Bug 修正見 [uidesign-changelog.md](uidesign-changelog.md)。

## 核心原則：Snoopy Museum 風格的「真義」

參考 Snoopy Museum Tokyo 時，**重點是 Snoopy，不是 Museum**。

- ✅ 卡通、漫畫、活潑、溫暖、手感插畫、親切、帶點童趣
- ❌ 博物館典雅、襯線體、文青冷靜、抽象幾何裝飾

## 字體

### 繁中相容性警告

**日文字體（Hachi Maru Pop、Kosugi Maru、Klee One 等）不含繁中字形。**
- 日文「数」(U+6570) ≠ 繁中「數」(U+6578)
- 強用日文字體顯示繁中會 per-character fallback 到 Noto Sans TC，字形不一致或根本沒生效

### 字體選擇

| 用途 | 字體 | 理由 |
|------|------|------|
| **中文標題** | **jf 粉圓體（open-huninn）** | JustFont 基於 Kosugi Maru 改造的繁中版本，SIL OFL 免費商用，真正的 Snoopy 卡通可愛感 |
| 英文裝飾 | Hachi Maru Pop / Kosugi Maru | 日文字體不能用在繁中，但可用於英文裝飾（年份、比分、背號） |
| 內文 | Noto Sans TC | 可讀性優先 |
| 不推薦 | Noto Serif TC | 襯線典雅、博物館文青感，偏離 Snoopy 方向 |
| 不推薦 | LXGW WenKai TC | 實際是傳統「楷書」字體（類似小學課本字），不是卡通手寫字 |

### jf 粉圓體套用範圍

**只改 Hero 區 + Section 標題 + Nav 標題 + Filter card 標題 + 頁尾標題**，其他（內文、數字、表格）維持 Noto Sans TC。

```css
@font-face {
  font-family: 'jf-openhuninn';
  src: url('https://cdn.jsdelivr.net/gh/marsnow/open-huninn-font@1.1/font/jf-openhuninn.woff2') format('woff2'),
       url('https://cdn.jsdelivr.net/gh/marsnow/open-huninn-font@1.1/font/jf-openhuninn.woff') format('woff');
  font-display: swap;
}
```

- Hero h1：56px / weight 500 / letter-spacing 4px
- Section 標題：20px / weight 500 / letter-spacing 1.5px
- **weight 用 500 而非 700**，粉圓體在 700 會略糊

## 色彩系統

| 角色 | 色碼 | 用途 |
|------|------|------|
| 背景淡米 | `#FDFCFA` | 頁面背景 |
| 白底 | `#FFF` | 卡片、區塊 |
| 主文字 | `#4A3728` | 內文 |
| 標題深棕 | `#3D3122` | 大標、頁尾 |
| 重點赤陶紅 | `#C2573A` | CTA、數字強調、favicon 主色 |
| 淡奶茶 | `#FDF6EE` | 膠囊背景、hover |
| 高鐵綠 | `#2B8A8A` | 高鐵按鈕 |
| 未來綠 | `#4A8B5C` | 狀態提示 |

### 球隊主色（single source of truth）

**所有主隊色都以 [index.html](../index.html) 的 `getTeamColor()` 函式為準**（目前在 `index.html:2291`），其他地方（`.chip.active[data-team=]` CSS、`design/*.html` CSS vars）若與之不同步，以 `getTeamColor()` 為準，不一致的地方應視為 bug 修掉。

| 球隊 | 主色 | 用於 |
|------|------|------|
| 中信兄弟 | `#FACD01` | chip、標準、card 名稱、主隊 dot |
| 統一 7-ELEVEn 獅 | `#C0611A` | 同上 |
| 樂天桃猿 | `#7B1A1A` | 同上 |
| 富邦悍將 | `#2B5FC3` | 同上 |
| 味全龍 | `#D8252D` | 同上 |
| 台鋼雄鷹 | `#16794A` | 同上 |

**使用規則**：

- 取色時呼叫 `getTeamColor(隊名)`（JS）或用 `.chip.active[data-team=]` 的 CSS 規則，**不要自己寫死 hex**
- 若要做主色淡底（例如球場徽章的主場上色），用 `color-mix(in srgb, <主色> 12%, #FFFAF0)` 保持奶茶底調性
- 新增 preview / 視覺稿時，**先 grep `index.html` 的 `getTeamColor`**，不要抄 `design/phase1-2-preview.html` 的 CSS vars（那份可能過時）

## 圖示與插畫

### 方向：彩色插畫 > 線條圖示

卡通彩色優先，單色線條（Tabler Icons 等）只適合 UI 輔助圖示（filter、search、arrow），**不適合主要視覺**。

### 資源選擇

| 資源 | 授權 | 用途 |
|------|------|------|
| **Fluent Emoji 3D** | MIT | Hero/Section 主視覺 PNG（獎盃、棒球等），跨平台一致 |
| Twemoji | CC-BY 4.0 | 替代原生 emoji，CDN：`https://cdn.jsdelivr.net/gh/jdecked/twemoji@latest/assets/svg/` |
| 自繪 SVG | — | Unicode 沒有或不符合需求的（棒球球棒、棒球場菱形） |
| OpenMoji | CC-BY-SA 4.0 | 手繪感 emoji 替代 |
| Flaticon Stickers | 需標註來源 | 精緻貼紙風（未採用） |

### Emoji 常見誤區

- **🏏 是板球（cricket），不是棒球**。Unicode **沒有獨立的棒球球棒 emoji**，Fluent / Noto / OpenMoji 全家族只有 Cricket game 板球圖組 → 要球棒只能自繪 SVG
- **Fluent `Stadium` 是通用綜合體育場**（圓頂/碗狀），不是棒球場菱形 → 要棒球場也只能自繪 SVG
- 原生 emoji 跨平台渲染不一致（Windows/Mac/Android 風格差異大），主要視覺務必換成 SVG 或 Fluent PNG

### Fluent PNG CDN

```
https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/{name}/3D/{slug}_3d.png
```

空格需 URL encode 為 `%20`。

## Hero 區

### 結構：動態資訊列

```
         中華職棒一軍例行賽 · 2026
              進場倒數
    [⚾] 今日 3 場  [📅] 剩餘 240 場  [🔥] 賽季進行中
              ● —— ◆ —— ●
```

- Eyebrow：年份 `· 2026`
- 主標：jf 粉圓體 56px
- 資訊列：今日場次 / 剩餘場次 / 賽季狀態（讀 RAW_DATA 動態計算）
- 背景 `#FFF9F0`、邊框 `#F0DFB8`、數字用赤陶紅粗體
- 兩側裝飾：左 **自繪 SVG 棒球手套**（赤陶紅），右 **Fluent 3D 棒球 PNG**
- 下方分隔線：保留幾何風 `● —— ◆ —— ●`（試過 `⭐ 〰 ⚾ 〰 ⭐` 太突兀被否決）

### `.snoopy-float` 定位

桌面版：`position: absolute; top: 50%; transform: translateY(-50%);`

手機版（≤768px）：取消絕對定位，改為 flex flow 排列
- `.hero` 加 `flex-wrap: wrap; gap: 12px`
- `.hero-content { width: 100%; }` 獨佔第一行
- `.snoopy-float { position: static; order: 2; }` 兩個 icon 排到第二行並排置中
- 隱藏 `hero-deco` 裝飾線（icon 並排已有裝飾效果）
- 尺寸縮小：手套 36px、棒球 32px

## Nav 導航列

- `position: sticky; top: 0; z-index: 100`，滾動時固定頂部
- 三個錨點連結：戰績 / 篩選 / 賽程，`smooth scroll` 跳轉
- 兼當「返回頂部」功能，不需額外 back-to-top 按鈕

## Section 標題

- 各隊戰績：**Fluent 3D 獎盃** icon + jf 粉圓體
- 賽程總覽：**自繪 SVG 棒球場** icon（菱形 + 四壘包 + 外野扇形 + 投手丘）
- `.section-icon` 基礎 22px / 手機 18px
- 細節多的 SVG（如棒球場）用 `svg.section-icon` 選擇器放大到 28px / 22px
- 棒球場 SVG 配色：外野 `#8FC271`、內野土 `#D4A574`、投手丘 `#C2573A`、壘包白

## Favicon

**inline SVG data URI**，不放獨立檔案避免 404 與快取問題。

- `<link rel="icon" type="image/svg+xml">` — 桌面分頁
- `<link rel="apple-touch-icon">` — iOS 加到主畫面（圓角方形 `rx='14'`）
- 視覺：赤陶紅 `#C2573A` 圓底 + 米白 `#FFF8F0` 棒球 + 赤陶紅縫線與縫針
- 縫線用 `Q` quadratic bezier 弧，縫針用 12 條小斜線模擬手縫細節
- data URI 中 `#` 需 URL encode 為 `%23`

## 佈局與結構

### 頁面區塊節奏
- 各區塊用 `.section-header`（jf 粉圓體標題 + 漸層橫線）劃分
- **戰績區白底、篩選區米白底**交替，用底色視覺區分

### 卡片網格
- 桌面 3 欄 / 平板 2 欄 / 手機 1 欄（不再使用表格）
- 日期分組：每日一個 `.date-group`，有橫線延伸的日期標題

### 卡片內部結構

```
┌─────────────────────────────────┐
│ 時間  ◉ 球場           [收藏]  │ ← 頂部欄
├─────────────────────────────────┤
│   🔵  VS / 比分   🟠           │ ← 對戰區（logo 圓形 + VS/比分）
├─────────────────────────────────┤
│  pill pill pill                 │ ← 詳情 pill
├─────────────────────────────────┤
│ 標籤               [購票][高鐵]│ ← footer（不再重複顯示球場）
└─────────────────────────────────┘
```

### 卡片特殊狀態
| 狀態 | 樣式 |
|------|------|
| 今日 | `card-top-today` 橘色頂部背景 |
| 延賽 | `card-top-postponed` 紫色頂部背景 + 延賽 badge |
| 已完賽 | 大字比分 `26px` 粗體，勝方赤陶紅、敗方灰 |

### 篩選區
- 分兩張 `.filter-card` 白底圓角卡片：
  - 「隊伍篩選」
  - 「條件篩選」
- 各有標題

### 統計列
- 白底圓角卡片式 summary bar
- 數字加大加粗（`15px` / weight `800`）
- `.stat-item` 包裹各項，圓點 `●` 分隔

### 戰績區
- 圓角表格排行榜
- 每列顯示：排名 + logo + 隊名 + 勝／敗／和 + 勝率 + 勝差（含底部 bar 視覺化）
- 領先者淡金底色

### 頁尾
- 深棕 `#3D3122` 背景
- 裝飾元素 `● —— ◆ —— ●`

## 圓潤風格（border-radius 規範）

| 元件 | 圓角值 |
|------|--------|
| Chip | `22px` |
| 按鈕 | `20px` |
| 下拉選單 / Toggle | `12px` |
| 卡片 | `16px` |

## Toggle 樣式

採膠囊（capsule）+ 白色 active 區塊（iOS 風格）。

## Badge 色系

| 類型 | 顏色 |
|------|------|
| 週六 | 藍 |
| 週日 | 紅 |
| 假日 | 赤陶 |
| 今日 | 橘 |
| 延賽 | 紫 |
| 未來 | 綠 |
| 已結束 | 灰 |

## 文案規則

- **隊名使用完整 3-4 字**（中信兄弟、樂天桃猿、富邦悍將、味全龍、台鋼雄鷹、統一獅）

## 預覽/對照檔案

- `icon-preview/preview.html` — 字體試穿、Hero 變體對照、Twemoji 插畫、Tabler Icons 網格
- `icon-preview/hero-icons-preview.html` — Hero 圖示候選方案並排比較（必須複用真實網站 class 結構，否則分隔點會繼承 body 色變黑偏離真實效果）
- `icon-preview/icons/` — 94 個 Tabler Icons SVG 備用

## 未來延伸方向

字體和圖示改完後可繼續卡通化的項目：

- [ ] 全站 emoji 改 Twemoji / Flaticon Stickers
- [ ] Section 分隔線改手繪波浪 / 星星 / 小閃電
- [ ] 抒情短語 → 親切口吻（「來看球吧！⚾」）
- [ ] 精緻直線陰影 → 柔軟卡通 drop shadow
