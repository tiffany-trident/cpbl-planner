# UI 實作紀錄與教訓

CPBL 2026 進場倒數網站的 commit 實作摘要、Bug 修正、開發教訓。設計原則見 [uidesign.md](uidesign.md)。

## Commit 實作紀錄

### 2026-04-23 — Phase 2-A 球場巡禮徽章 + 個人中心殼（分支 `feat/phase2a-venue-badges`）

Phase 2-A 實作進「我的」tab，同時把 tab 升級為 sub-tabs 個人中心殼對齊原 `design/phase1-2-preview.html` Phase 1-D 設計。

#### 功能總覽

| 區塊 | 決策 |
|------|------|
| IA | 「我的」tab 從單頁 stack 升級為 4 個 sub-tab（統計 / 徽章 / 打卡紀錄 / 收藏），純 CSS `.active` toggle 切換；打卡紀錄 + 收藏為 placeholder，待 Phase 1-D 延伸實作 |
| 球場徽章 layout | 4 欄 × 3 列網格（11 球場 + 1 bonus 進度環）填滿 `.my-view` 1200px 容器內側；max-width 720px 選項被否決以留徽章牆完整感 |
| visited / locked 差異化 | visited 暖色漸層底（`#FFF5DC` → `#FFFEFA`） + 2px 赤陶橙實線框 + 柔光 shadow + **右下角 72px 半透明 `bb-checkin` 印章**（opacity 0.28 / rotate 8°，跟打卡功能的 `.checkin-stamp` 同風格）；locked 奶茶灰底 + 虛線 + 無 shadow，icon grayscale 0.45 |
| 主隊識別 | 有明確主場的 6 座（天母/味全、新莊/富邦、桃園/樂天、洲際/兄弟、亞太/統一、澄清湖/台鋼）在球場名前顯示隊徽 22px；大巨蛋（6 隊共用）+ 4 座副主場（嘉義市、斗六、花蓮、台東）不顯示隊徽 |
| bonus 格 | SVG 進度環（r=28、6px stroke、赤陶紅弧），中央顯示 `N/11`，取代最早的 ✨ emoji 版 |
| Field note | `.vp-card` header 下方 pill「你最常去 XX，已達成 N 次」— 跨球場統計，跟主隊無關 |
| Hero 招呼語 | 全站 hero `.hero-greet` 加「哈囉，XX 迷 👋」（15px 赤陶紅），主隊暱稱 map（兄弟迷 / 獅迷 / 猿迷 / 悍將迷 / 龍迷 / 雄鷹迷），只在設定主隊時顯示 |
| 重疊整併 | 原初版本把招呼語放在 `.my-view` 內 hero，但跟頂部 nav 的主隊資訊重複 → 改移到全站 hero 一次，`.my-view` 直接從 tabs 開始 |
| Section header 調整 | 拿掉 `.my-view` 原本的「我的看球故事」section header —  與 hero 內容重複，頁面視覺被切兩段 |

#### 設計 exploration

- `design/phase2a-badges-preview.html` — 從 A（網格）vs A+B（地圖）→ 純 A → 比較 A-F 6 種 visited 角標樣式 → 定案 G「球場印章」對齊打卡 icon 語彙

#### 開發教訓

- **球隊主色 single source of truth 散在多處**：`index.html:getTeamColor()` 是 production 真相來源（味全 `#D8252D` 紅），但 `design/phase1-2-preview.html` CSS vars 過時（寫成 `#6D30B8` 紫）、`index.html` 內 `.chip.active[data-team=]` 又第三套。我先抄 preview vars 給味全龍上紫色被糾正。根治：`docs/uidesign.md` 加「球隊主色」章節正規表 + 指明 single source of truth；`phase1-2-preview.html` CSS vars 同步到 production；memory 加例外規則「動到球隊色一律 grep `getTeamColor` 不抄 preview」。教訓：docs 沒寫清楚的 convention，preview file 就不是權威。
- **手繪 Taiwan SVG 是自找麻煩**：A+B 地圖版嘗試手刻 Taiwan path 兩次都被「很不像」退回，最終 user 放棄地圖版改走 β（北中南東 lanes），又再回到純 A 網格。教訓：複雜 real-world shape 不要手繪，要嘛匯入 CC-BY SVG 要嘛換別的視覺化方式。
- **隨機 demo data 會被當成邏輯**：preview 早期在天母 cell 隨機貼「首達」標章，user 問「為什麼」我才意識到自己在 demo data 裡塞了跨 Phase 的 placeholder。根治：寫 `feedback_preview_demo_data_consistency.md` — demo 資料每格 meta 都從同一份假設推導，未來階段的 feature 只能在 legend 示意。
- **sub-tabs 殼先做、tab 內容後填**：user 觀察現況 stack 跟原設計有偏離，選擇補回 4-tab 個人中心殼而非維持 stack。打卡紀錄 + 收藏 先放 placeholder，未來 phase 再填內容。教訓：整體架構早做一點會比事後重構輕鬆。
- **重複訊息反覆收斂**：頁面最上先有「我的看球故事」section header，中間 hero 又有「哈囉，XX 迷」和「主隊：XX 變更」，下面 stats 橫列又顯示 `2 / 11` `1.000` 跟 tab 內容重複 — 三層重複迭代 debug 完才乾淨。教訓：iteration 時要主動檢查「這個資訊在其他地方已經出現了嗎？」

#### Footer attribution

production 部署前在 footer 加 Flaticon 球場 icon attribution（`icon-preview/icons/stadium-flaticon-484466.png` 用於 visited/locked cell + card header，符合 Free License 要求）。

### 2026-04-22 `0946022`..`227a24e` — Phase 2-B 我的看球故事（8 commits + merge `7ddca8d`）

Phase 2-B（現場戰績卡 + Streak）實作到分支 `feat/phase2-stats-streak`，已整批 merge 到 main。流程：3 個 feature commit（tab 框架 → 戰績卡 → streak banner）→ 2 個 fix（下一場排除已完賽 / CSS class 衝突）→ design exploration docs → E2 大卡重構 + 顏色與 nav icon → stats section 隱藏修正。

#### 功能總覽

| 區塊 | 決策 |
|------|------|
| IA | Nav 新增「我的」tab（`bb-favorite` 小圖示 14x14），data-view="my" 切換隱藏戰績表 / 篩選 / stats / 賽程卡片。URL hash `#my` 可書籤；initMyViewFromHash + hashchange listener 處理前進/後退。Personal strip、打卡歷史 list 留待未來 iteration |
| 戰績卡 layout | E2 左右分欄（720px 寬）：左欄勝率 + W/L/T，右欄主隊賽季近 10 場 dot + 下一場；header 整合 team logo + streak pill（條件 count ≥ 2） |
| 視覺主題 | 主題 1 暖色漸層：`linear-gradient(135deg, #FFFEFB → #FFF5E6)` + 米色邊框 + 柔陰影，跟 hero 氛圍一致 |
| Streak 邏輯 | 只計主隊出賽 + 有打卡 + 非延賽，依日期+時間排序 current 連勝/敗；count < 2 或首筆是和局不顯示 pill |
| Dot 邏輯 | 原本 A「只算打卡」在打卡稀疏時 label 誤導；改 B「主隊賽季近 10 場完整戰績」label 改「主隊賽季近 10 場」；底部加 field note「你現場見證最近 N 場 W L W · 日期範圍」（最多 5 場）保留現場 signal |
| 顏色對調 | 勝 / 勝率 `#1A6B3A` 綠 → `#C2573A` 赤陶紅（台灣傳統紅=吉祥，跟站內主色呼應）；敗 `#B52828` → `#1A6B3A` 綠；和維持灰 `#9B8E7E` |
| 下一場 | `isFuture && !postponed && !completed`；曾漏 `!completed` 導致今天已完賽場次被當下一場 |

#### 設計 exploration

三份 preview 記錄決策過程：
- `design/streak-banner-preview.html` — 5 個整體主題（暖色漸層 / 米底清爽 / 赤陶紅 / 手帳貼紙 / scoreboard）+ 里程碑 Lv1/2/3 動態強化
- `design/my-view-bigcard-preview.html` — E1/E2/E3/E4 四種大卡 layout 對比
- `design/my-view-e2-themes-preview.html` — E2 × 5 主題最終對比

#### 開發教訓

- **「空感」不是加留白可以解決的**：原本 streak banner + 小戰績卡兩個 480px 置中元件被反映「下半頁空曠」。解法不是加 padding，而是重排 layout — 整合成 720px 大卡，塞進最近 10 場 + 下一場 + field note，資訊密度才夠。教訓：頁面空感通常要重排內容，不是加留白。
- **`.n.l` class 名稱衝突**：敗的數字 class `<span class="n l">` 同時被 `.l` 的 label CSS（11px 灰字）命中，specificity 相同後者贏，敗的數字變小字。rename 為 `num/lbl` + `win/loss/tie`。教訓：class 名避免單字母、小心 specificity。
- **dot 選項三方權衡**：A 只算打卡（簡單但稀疏時 label 失真）/ B 主隊賽季全部（資訊量足）/ C dot + 去過標記（最豐富但打卡不在近 10 場內就 degrade）。最後選 B + field note 兼顧兩個 signal。教訓：資料稀疏情境要預先考量，避免 label 與實際內容脫節。
- **切 tab 漏隱藏 #stats**：`MAIN_VIEW_SECTION_IDS` 只列了 standings-wrap / filters / games，漏掉 `#stats` 獨立 section。教訓：加新 top-level section 時要回頭檢查 tab switch 清單。
- **原 design 稿 p1home 更完整**：使用者提醒 `design/phase1-2-preview.html` 有 Personal strip + 通知卡 + 我的中心頁的 dashboard IA，本次只做了「我的中心頁」的一部分。當時選 C 方案漸進演進（保留 tab + 未來加 Personal strip），C 方案的 Personal strip 還沒做。

### 2026-04-22 `97f5dae`..`50e656f` — Phase 1 個人化功能（5 commits + merge `4e7c11a`）

Phase 1 engagement roadmap 實作到分支 `feat/phase1-personalization`。5 個 commit 依序：Schema v1 → 篩選記憶 → 場次收藏 → 主隊設定 → 觀戰打卡。當日整批 merge 到 main。

#### 視覺決策總表

| 元件 | 決策 |
|------|------|
| 收藏 icon | `bb-favorite` SVG（svgrepo 139073，棒球 + 投球動線）+ 已收藏時卡片 2px 赤陶紅 `outline`（非 border，避免 layout shift）|
| 打卡 icon | `bb-checkin` SVG（svgrepo 480624，棒球場俯瞰）+ 已打卡時卡片右下 `rotate(8deg)` / `opacity: 0.30` 半透明蓋章 |
| 主隊標記 | `cap-mainteam` = Phosphor `baseball-helmet-fill`（MIT），side view 含耳罩。戰績表主隊列隊名後 20px，顏色跟該隊主色（`getTeamColor`）|
| Modal | 白底 24px 圓角 + 半透明黑遮罩（`rgba(61,49,34,0.6)`）。首次進站主隊 modal 強制選或跳過（點背景不關、ESC 不關），已設後可點外/ESC 關閉 |
| Footer 精簡 | 移除冗餘 badge（今日/週六/週日/已結束/未來），保留假日與延賽；賽事記錄 pill 搬到左下與 tags 同區 |
| 球隊主色 | 對齊 CPBL 官方：中信 `#FACD01`、味全 `#D8252D`、樂天 `#7B1A1A`（接受中信黃白底對比度 1.3:1 的 tradeoff） |

#### 開發教訓

- **「先讀 design sprite 再選 icon」規則在 Phase 1 中途才加進 CLAUDE.md**：Step 3 當初憑印象用 ⭐，被指正才知道 `design/phase1-2-preview.html` 視覺稿已備好 `bb-favorite` SVG；Step 5 規劃時又用 📍 shorthand 引起誤會。規則已硬化（commit `2e46251`）納入「開工前必讀」章節與「客製 icon 命名表」。
- **stamp opacity 初版 0.18 太淡**：沒開瀏覽器目視驗證就交差，使用者反映後 debug 才知道 DOM 正常但 opacity 太低。之後調 UI 視覺必須開瀏覽器或 DevTools 實際看，不能只靠 brace/paren 結構檢查當作通過驗證。
- **`sno` ↔ 日期對應必須查 `RAW_DATA`**：Step 5 demo 指令誤把 sno 050/051 當 4/19 場次（實際是 4/21，commit `5d5074b` 訊息原本就寫錯）。後續涉及 sno 要先 grep `RAW_DATA` 對照。
- **中信官方黃 `#FACD01` 白底文字對比度 1.3:1**：視覺最「中信」但 WCAG 不及格。Tiffany 確認接受這個 tradeoff（文字用 `font-weight: 600` 略補）。
- **CSS 特異性：子元素背景蓋住父層 inset box-shadow**：整圈紅框原本用 `box-shadow: inset 0 0 0 2px` 但 `.card-top` 的 `background: #FFFAF2` 把頂部紅框遮住，看起來只剩下半部。改用 `outline: 2px solid; outline-offset: -2px;` 解決（outline 畫在最外層、不被子元素蓋）。

### 2026-04-22 `2e46251` — 強化「開工前必讀」規則

因為連續兩個 Step（⭐→bb-favorite、📍→bb-checkin）都犯「憑印象選 emoji」的錯，CLAUDE.md 把「開工前必讀」升級為硬規則，明確要求任何 icon / 視覺元件選擇前先查 `design/phase1-2-preview.html` 最上方的 `<defs>` SVG sprite 區，並新增「客製 icon 命名表」（bb-favorite / bb-checkin / cap-mainteam 正規定義）。記憶檔 `feedback_read_docs_first.md` 同步擴充。

### 2026-04-20 `3fec3c0` — 卡片「📋 賽事記錄」pill

已完賽場次卡片 footer 多一顆米底赤陶字的「📋 賽事記錄」pill，點擊展開 CPBL 賽事記錄（連勝連敗、個人里程碑）。

| 項目 | 決策 |
|------|------|
| 觸發條件 | `g.completed && g.sno && BRIEFINGS[g.sno]` — 只在已完賽且有賽事記錄內容時顯示 |
| 位置 | `card-footer-buttons` 最右（購票/高鐵為未來場次，跟賽事記錄互斥不會同時出現） |
| 視覺 | 20px 圓角，`#F5EEDE` 米底 + `#E8DDBE` 細框；hover `#ECE3CC` |
| Popover 架構 | 複用天氣 popover 模式：桌面彈窗（360px 寬）、手機 bottom sheet（70vh 高、可滾動） |
| 內容渲染 | `innerHTML` 直接塞 CPBL HTML（`<p>`、`<span>`、`<br />`），`.briefing-body p` 加 margin 讓段落有間距 |
| 資料 key | RAW_DATA 加第 13 欄 GameSno（3 位零填），索引 `const BRIEFINGS` 對應物件 |

詳見 [briefings.md](briefings.md)。

### 2026-04-17 — Hero 手套圖放大

使用者反映手套圖偏小，存在感不足。調整尺寸：

| 裝置 | 原尺寸 | 新尺寸 |
|------|--------|--------|
| 桌面 | 78px | 108px |
| 手機 | 36px | 52px |

右側棒球（72 / 32px）維持不變，讓手套視覺上更像主角、棒球當配角。使用者看過後確認比例 OK。

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
