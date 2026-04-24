# 功能清單

CPBL 2026 進場倒數目前已實作的功能。

## 篩選與檢視

- **隊伍 / 對手多選**：chip 按鈕，可同時篩多隊
- **球場／月份下拉**：dropdown 選擇
- **週末／週末+國定假日**：toggle 篩選，台灣 2026 國定假日內建
- **場次狀態三段切換**：未來場次（預設）／全部／已結束

## 卡片顯示

- **已完賽**：比分（勝方奶茶棕、敗方灰）+ W/L/SV/MVP 彩色 pill 標籤
- **延賽**：紫色 badge，不顯示比分
- **今日**：橘色 badge + 淡橘背景高亮
- **同日多場分組**：
  - 桌面版：日期僅首場顯示 + 分隔列
  - 手機版：日期標題分組
- **狀態 badge**：僅「全部」模式顯示（未來／已結束／延賽）

## 統計列

- **篩選結果／週末／假日**：依篩選條件計算
- **已完賽／未來／延賽**：從全部資料計算（不受篩選影響）

## 各隊戰績排行榜

- 位置：頁頂 Hero 之後
- 依勝率排序
- 表格欄位：排名編號、球隊（logo + 名稱）、勝、敗、和、勝率、勝差 GB
- 領先者淡金底色
- 資料來源：`https://cpbl.com.tw/standings/season`

## 外部連結按鈕

### 購票按鈕
- 顯示條件：未來非延賽場次
- 連結依主場球隊對應售票網站
- 連結清單見 [external-links.md](external-links.md)

### 高鐵訂票按鈕
- 顯示條件：未來非延賽場次、球場有對應高鐵站
- 花蓮場次不顯示（花蓮無高鐵）
- 球場→高鐵站對應見 [external-links.md](external-links.md)

## 球場天氣預報

- API：Open-Meteo（即時）
- 範圍：未來 7 天內場次
- 內容：
  - 72hr 內 → 逐時溫度 + 降雨率
  - 3~7 天 → 全日概況
- 快取：localStorage 3 小時
- 詳見 [weather.md](weather.md)

## 賽事記錄

- 位置：已完賽場次卡片 footer 的「📋 賽事記錄」pill
- 點擊展開：CPBL 連勝連敗、里程碑紀錄
- 詳見 [briefings.md](briefings.md)

## 主場主題日

- 位置：卡片上顯示主題日 badge
- 詳見 [theme-days.md](theme-days.md)

## 個人化功能（Phase 1）

localStorage 儲存 schema v1，讓網站記得使用者身份與偏好。未來 Phase 4 跨裝置同步會沿用此 schema。分支 `feat/phase1-personalization`，已 merge `4e7c11a`。

### 主隊設定
- 首次進站彈出 modal（6 隊 3×2 網格）選主隊；可按「先跳過」
- Nav 列：未設 → 虛線「⚾ 設定主隊」按鈕；已設 → logo + 名稱 + 「切換」連結（奶茶底實心 pill）
- Hero 資訊列多一格「[logo] 今日 N 場 · 剩餘 N 場」
- 戰績表主隊列隊名後加打擊頭盔 icon（Phosphor `baseball-helmet-fill`），顏色與隊名同色

### 場次收藏
- 卡片 card-top 右上 `bb-favorite` SVG 按鈕（svgrepo 139073 棒球 + 投球動線）
- 未收藏：淡棕輪廓；已收藏：赤陶紅實心 + 整張卡片 2px 赤陶紅 `outline`
- 已完賽／未來皆可收藏（延賽除外）
- 篩選區「只看收藏」checkbox

### 觀戰打卡
- 已完賽場次 footer pill「打卡」→ 打卡後變赤陶紅實底「我在現場」
- Modal 表單：
  - 座位（三壘／一壘／本後／左外野／右外野／包廂／其他，chip 多選）
  - 同行者（文字，可空）
  - 5 星評分
  - 心得（200 字，含計字）
  - 照片 placeholder（未實作）
  - 儲存／取消／刪除打卡（confirm）
- 已打卡卡片右下角：半透明赤陶紅 `bb-checkin` SVG 蓋章（opacity 0.30、rotate 8°）
- 篩選區「只看已打卡」checkbox

### 篩選記憶
- 所有篩選條件（隊伍／球場／月份／週末／假日／只看收藏／只看已打卡／狀態）寫入 `userState.lastFilter`
- 下次進站自動套回上次篩選
- 重設按鈕清除記憶

### 球隊色修正（對齊 CPBL 官方）
| 隊 | 原值 | 新值 | 修正原因 |
|-----|------|------|---------|
| 中信兄弟 | `#b7950b` 暗金 | `#FACD01` 官方鮮黃 | 原色太暗 |
| 樂天桃猿 | `#b91c1c` 亮紅 | `#7B1A1A` 酒紅 | 原本跟味全紅撞色 |
| 味全龍 | `#7c3aed` 紫 | `#D8252D` 亮櫻桃紅 | 原本誤配紫色 |

### 卡片 footer 精簡
- 移除冗餘 badge：今日／週六／週日／已結束／未來（日期 header + card-top 色已足夠）
- 保留：假日名稱、延賽（有額外資訊）
- 賽事記錄 pill 搬到左下，與 tags 同區

## 個人化功能（Phase 2-B · 我的看球故事）

Nav 新增「我的」tab 切換進入「我的看球故事」頁面。只計主隊出賽且有打卡的場次計算戰績。分支 `feat/phase2-stats-streak`，已 merge `7ddca8d`。

### Tab 切換
- Nav「我的」加 `bb-favorite` 小圖示（14×14 sprite，`currentColor` 跟隨文字色）
- 點擊後隱藏賽程區塊（standings / filters / stats / games），顯示「我的看球故事」
- URL hash `#my` 可書籤、可分享；hashchange listener 處理前進/後退

### 現場戰績 E2 大卡（720px 寬整合卡）

Header：主隊 logo + 名稱 + streak pill（條件 count ≥ 2 才顯示）

左欄：
- 勝率大數字（赤陶紅 `#C2573A`，Inter 800 / 56px）
- 勝率算法 `wins / (wins + losses)`，和場不計入分母；分母 0 顯示 `--`
- W（赤陶紅）/ L（綠）/ T（灰）三欄

右欄：
- 主隊賽季近 10 場 dot（赤陶紅勝 / 綠敗 / 灰和 / 虛線空位）— 不限打卡
- 下一場主隊比賽（日期、球場、對戰）— 排除已完賽與延賽

底部 field note：「你現場見證最近 N 場：W L W · 日期範圍」
- 最多顯示最近 5 筆打卡
- 跟主隊賽季 dot 並存，兩個 signal 互補（主隊近況 / 你現場近況）

### Streak pill
- 只計主隊出賽 + 有打卡 + 非延賽場次，依日期+時間排序
- 從最後一筆往前算 current 連勝/連敗，遇到不同結果或和局即中斷
- 連勝用 🔥、連敗用 ☁️
- `count < 2` 或最後一筆是和局不顯示

### Empty state（3 種）
- 未設主隊 → 「先選一隊作為你的主隊」+ 設定主隊按鈕
- 有主隊無打卡 → 「還沒打卡紀錄」+ 連回賽程連結
- 打卡但主隊沒出賽過 → 「主隊還沒出現在你的現場」

### 顏色語意（對調原綠勝紅敗慣例）
| 結果 | 顏色 | 原 → 新 |
|------|------|---------|
| 勝 / 勝率 | 赤陶紅 `#C2573A` | `#1A6B3A` → `#C2573A`（台灣傳統紅=吉祥，跟站內主色呼應） |
| 敗 | 深綠 `#1A6B3A` | `#B52828` → `#1A6B3A` |
| 和 | 灰 `#9B8E7E` | 不變 |

## 個人化功能（Phase 2-A · 球場巡禮徽章 + 個人中心殼）

分支 `feat/phase2a-venue-badges`。在 Phase 2-B 的「我的」tab 內再擴充：

### 個人中心殼（sub-tabs 架構）

原本「我的」tab 是單卡直接顯示，這次改成 4 個 sub-tab 框架（對齊 `design/phase1-2-preview.html` 的 Phase 1-D 設計）：

- **統計** — Phase 2-B 戰績大卡（預設 active）
- **徽章** — Phase 2-A 球場巡禮（新）
- **打卡紀錄** — placeholder（Phase 1-D 規劃中）
- **收藏** — placeholder（即將推出）

Tab 切換純 CSS（`.active` class toggle），無 re-render。URL hash 仍走 `#my`，sub-tab 狀態不持久（每次進入預設 `stats`）。

### 全站 hero 招呼語

`.hero-greet` 在全站頂部 hero 的「中華職棒一軍例行賽 · 2026」上方顯示「哈囉，XX 迷 👋」。
- 只有設定主隊時才顯示，未設定自動隱藏
- 主隊暱稱 map（`TEAM_FAN_NICKNAME`）：兄弟迷 / 獅迷 / 猿迷 / 悍將迷 / 龍迷 / 雄鷹迷
- 全站可見（非限定「我的」tab），避免跟 `.my-view` 內容的主隊資訊重複

### 球場巡禮徽章（`.vp-card`）

4 欄 × 3 列網格填滿 `.my-view` 1200px 容器內側（11 球場 + 1 bonus 格）：

- **球場清單**（`VENUES_2026`）：大巨蛋、天母、新莊、樂天桃園、洲際、斗六、嘉義市、亞太主、澄清湖、花蓮、台東
- **主場主隊 map**（`VENUE_HOME_TEAM`）— 只有主場占比 ≥ 95% 的 6 座列入：
  - 天母 → 味全龍 / 新莊 → 富邦悍將 / 樂天桃園 → 樂天桃猿 / 洲際 → 中信兄弟 / 亞太主 → 統一 7-ELEVEn 獅 / 澄清湖 → 台鋼雄鷹
  - 大巨蛋（6 隊共用 28/19/17/14/12/10%）+ 4 座副主場（嘉義市、斗六、花蓮、台東）→ 無隊徽顯示

### Cell 狀態

**visited**：
- 背景暖色漸層（`#FFF5DC` → `#FFFBEE` → `#FFFEFA`）
- 2px 實線赤陶橙 `#E2A36C` 邊框
- 柔光 shadow `0 3px 14px rgba(226, 163, 108, 0.22)`
- **右下角球場印章**（bottom-right 72px `bb-checkin` sprite，opacity 0.28，rotate 8°，與 `.checkin-stamp` 同風格）
- cell 內容：球場 icon（68px flaticon PNG）+ 主隊 logo + 球場名 + 去過次數 + 最近日期 / 主隊現場戰績

**locked**：
- 背景 `#F2EBDA`，1.5px 虛線 `#CBB999`，無 shadow
- icon grayscale 0.45，球場名灰化
- 底部「還沒去」，`margin-top: auto` 推到卡底

**bonus 格**：
- 漸層暖底，進度環 SVG（r=28px，6px stroke，赤陶紅弧 / 淡金底）
- 中心顯示 `N/11`
- 下方文字「集滿 11 座 · 年度巡禮徽章」

### Field note

`.vp-card` header 下方 pill：「你最常去 XX，已達成 N 次」
- 從所有 checkins 統計球場次數取最高者
- 與主隊無關（不管主隊是誰）

### 資料邏輯

- `calcVenueStats(venue)`：遍歷 `userState.checkins`，回傳 { count, lastDate, wins, losses }；W-L 只計算主隊出賽且已完賽的場次
- `findTopCheckinVenue()`：跨球場統計，回傳最多次數的球場
- 所有 render 即時 `document.querySelectorAll` 不做快取（`userState` 變動時 `renderMyView()` 重新渲染）

### Production 注意

- 球場 icon 用 `icon-preview/icons/stadium-flaticon-484466.png`（Flaticon Free 授權，footer 需 attribution）
- `bb-checkin` sprite 已在主程式（line ~485），印章直接 `<use href="#bb-checkin"/>`
- 主隊 logo 用 `TEAM_LOGO[team]` — 遠端 `cpbl.com.tw` 圖片
- cpbl-planner.html 必須跟 index.html 保持同步

## 個人化功能（Phase 1-D 收藏 tab · 篩選 segment 重構）

分支 `feat/phase1d-favorites-tab`。補上原 Phase 1-D 設計的「收藏」sub-tab 內容 + 篩選區 UX 改進。

### 我的 → 收藏 sub-tab

原本是 placeholder，這次填入實際列表。

- **資料來源**：`userState.favorites` 陣列 → 對應 `allGames` 撈出完整場次
- **分組**：「即將到來」（未來 + 非延賽，依日期 asc）/「已過」（已完賽或延賽，依日期 desc）
- **Row layout**：`grid-template-columns: 72px 1fr 40px` — 日期 block | 對戰 + 場地時間 | 取消收藏 ★
  - 日期 block：`月/日` 赤陶紅 Inter 粗體 + `週X` 小灰字
  - 對戰：已完賽顯示比分（W 赤陶紅 / L 綠 / T 灰，沿用 Phase 2-B 配色），未完賽顯示 `VS`
  - 延賽場次：場地後加「延賽」小 pill
- **互動**：點 `.card-fav-btn`（★）→ `toggleFavorite()` → row 立即移除 + list 重新渲染
- **`toggleFavorite()` 擴充**：同時 call `render()`（主賽程）+ `renderMyView()`（收藏 tab），兩邊保持同步
- **空 state**：沒收藏過 → 提示「去賽程頁面點卡片右上角的 ⭐ 收藏」

### 篩選區「收藏／打卡」從 checkbox 改 segment

原本篩選區有 2 個獨立 checkbox `f-favorites-only` 與 `f-checkins-only`（可同時勾，但實際組合少用），改為一個互斥 segment control。

- **UI**：3-段 `.toggle-group`（`全部 | ⭐ 只看收藏 | ◉ 只看已打卡`），跟既有「場次狀態」segment 同 CSS class + 同樣式
- **Icon**：`bb-favorite` 手套 + `bb-checkin` 球場俯瞰圖
- **數字 badge**：旁邊顯示實際收藏 / 打卡數，`ob-count:empty` 時自動隱藏
- **Schema**：`userState.lastFilter` 加 `ownership: 'all' | 'favorites' | 'checkins'`；`applyFilterToUI` 自動從舊 `favoritesOnly` / `checkinsOnly` 遷移
- **state var**：`ownershipFilter` 取代原 2 個 checkbox query
- **Reset 按鈕**：同步重設成「全部」

### 篩選區排版壓縮

讓 5 個條件（隊伍 / 球場 / 月份 / 場次狀態 / 日期 / 收藏·打卡）+ 重設按鈕排成一列：

- `.filter-card-row` gap 16 → 10/12
- `.filter-row` gap 14 → 10
- `.cb-row` gap 14 → 10
- `.filter-group` label→content gap 7 → 5
- label 字 12 → 11，select padding 10/16 → 8/14、min-width 140 → 120
- `.toggle-btn` padding 8/20 → 6/12、font 13 → 12.5
- `.btn-reset` padding 10/22 → 8/16

總寬從 ~1084px 壓到 ~930px，1200px 容器內可平鋪成一列。
