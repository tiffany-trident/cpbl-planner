# 中職相關新聞

讓球迷在站內快速瀏覽 CPBL 相關新聞標題，點擊導回原始媒體閱讀。

## 版權原則（硬規則）

本功能是**連結聚合器**，不是內容轉載。與 Google News、LINE Today 相同模式。

- **只儲存/顯示**：標題、來源媒體名、發布時間、**原文連結**
- 點擊 → 開新分頁（`target=_blank rel=noopener noreferrer`）導回**原始媒體網站**看全文
- **絕不**儲存或顯示：文章全文、內文段落、原站圖片、縮圖
- 頁面底部固定顯示著作權聲明：「新聞標題與連結由各原始媒體提供，著作權屬原媒體所有，點擊前往原站閱讀。」

### 為什麼這樣安全

- 台灣《著作權法》第 9 條：「單純為傳達事實之新聞報導所作成之語文著作」不受著作權保護；本功能不碰評論／特稿內文，只做標題導流。
- 採用**媒體自己提供的 RSS**：出版方主動提供 RSS 即是邀請閱讀器／聚合器抓取，顯示「標題＋導回原站連結」正是其預期用途。

### 為什麼不用 Google News RSS

Google News RSS 技術上最好抓，但其 feed 內 `<copyright>` 條款**明文限制**只能用於「個人、非商業的個人閱讀器（personal feed reader for personal, non-commercial use）」，並聲明「Any other use of the feed is expressly prohibited」。把它轉貼到公開網站不符授權範圍，故**排除**。（驗證日：2026-07-14）

### FeedBurner ≠ Google News RSS

中央社／ETtoday 的官方 feed 走 **FeedBurner**（`feeds.feedburner.com/...`）投遞。FeedBurner 是 Google 代管的**投遞**服務，但 feed 內容為**媒體自家**發佈、`<copyright>` 為該媒體署名、**無使用限制條款**——與 Google News RSS 聚合他人內容並加限制條款本質不同，屬「出版方主動提供、邀請聚合」，符合本功能版權原則。（驗證日：2026-07-21）

## 資料來源

| 來源 | RSS 端點 | 標題格式 | 狀態 |
|------|---------|---------|------|
| 自由時報 體育 | `https://news.ltn.com.tw/rss/sports.xml` | CDATA | 使用中（feed 無限制條款，UTF-8 正規 XML） |
| 中央社 體育 | `https://feeds.feedburner.com/rsscna/sport` | 純文字 | 使用中（2026-07-21 加入；FeedBurner 投遞，見上） |
| ETtoday 運動 | `https://feeds.feedburner.com/ettoday/sport` | CDATA | 使用中（2026-07-21 加入；`pubDate` 格式異常但 `DateTimeOffset.Parse` 可解） |

未來要加來源：先確認該媒體 RSS 無限制條款，再加進 `scripts/fetch-news.ps1` 的 `$Feeds` 陣列即可（含 `name` 與 `url`）。標題不論純文字或 CDATA 皆由 `SelectSingleNode('title').InnerText` 處理。

**已驗證排除**（2026-07-21）：三立 SETN（`RSS.aspx` 已 302 導回首頁）、TSNA（站上無公開 RSS 端點）、聯合報 UDN（feed 可連但 `<item>` 為空、形同停用）。

## 過濾邏輯

自由時報體育 RSS 涵蓋所有運動（世足／NBA／網球…），需過濾出中職相關。

- 條件：標題或 RSS 導言（description，**不儲存**，僅用於判斷相關性）符合 `$CpblRegex`
- `$CpblRegex = 中職|中華職棒|職棒|中信兄弟|樂天桃猿|富邦悍將|統一7|統一獅|味全龍|台鋼雄鷹`
- **只用全名**（中信兄弟…）不用裸短名（統一／富邦／樂天），避免撞到其他組織或他項運動球隊（例：富邦勇士是籃球）
- 範圍決策（2026-07-14）：**審中職相關即可**——含亞運／旅外／選秀等球迷關心的廣義棒球新聞都收，不限縮到聯盟賽事本身

## 球隊標記（`teams` 欄位，驅動前端球隊篩選）

每則新聞在 `fetch-news.ps1` 標上 `teams` 陣列（0～多隊），前端球隊篩選依此比對。

- **只比對標題**（不用 description）：description 是全文導言，會 name-drop 戰績表／別場比賽的隊名，造成嚴重過度標記；篩選要**精準度優先於召回**（篩富邦不該跳出「兄弟 vs 台鋼」只在內文提到富邦的新聞）。只用標題也讓 fresh 與 archived 標記一致。
- **標記是標題的決定性函式**：archived 項目每次執行都用標題重算，故 pattern 若日後調整，舊資料自動跟上、也自癒早期寫壞的值。
- **單字暱稱**：`獅／猿／鷹` 在中職標題語境安全，直接收；`龍／象／將` 撞投手暱稱或常用字（魔神龍、武將…），需 2+ 字全稱（`龍隊`）。`富邦` 裸名在已通過 CPBL 過濾的語境幾乎必為悍將，收。
- team key **必須**與 `index.html` 的 `getTeamColor()` 完全一致。
- 命中 0 隊的綜合新聞（MLB／旅外／明星賽／只有球員名的標題）`teams` 為 `[]`，**僅在球隊「全選」時顯示**（見前端）。

`$TeamPatterns`（正規定義在 `fetch-news.ps1`）：中信兄弟=`中信兄弟|兄弟`、統一獅=`統一獅|統一7|獅隊|獅`、樂天桃猿=`樂天桃猿|樂天|桃猿|猿`、富邦悍將=`富邦悍將|悍將|富邦`、味全龍=`味全龍|味全|龍隊`、台鋼雄鷹=`台鋼雄鷹|台鋼|雄鷹|鷹`。

## 資料流（沿用比分自動更新管線）

瀏覽器直接抓 RSS 會撞 CORS，因此跟比分一樣走本機抓取：

```
Windows Task Scheduler
  └─ scripts/update-scores.bat
       ├─ scripts/update-scores.ps1   (比分 → RAW_DATA / briefings)
       └─ scripts/fetch-news.ps1      (RSS → data/news.json)   ← 新聞為次要步驟，失敗不擋比分 commit
  → git add index.html cpbl-planner.html data/briefings.json data/news.json → commit → push
主頁載入時 fetch('data/news.json')（同 theme_days.json 的 runtime 載入模式）→ renderNewsView()
```

- `fetch-news.ps1` 跨次累積：讀舊 `data/news.json`，依 **URL 去重**（新蓋舊），保留 **45 天**（`$KeepDays`），上限 **100 則**（`$MaxItems`），依 `pubDate` 由新到舊排序
- **編碼**：`fetch-news.ps1` 存成 **UTF-8 with BOM**（PS 5.1 才能正確讀含中文的關鍵字 regex）；輸出 `data/news.json` 為 UTF-8 no BOM
- **CDATA 取值**：LTN／ETtoday 的 title/description/link 是 CDATA，`$item.title` 會回傳 XmlElement，須用 `SelectSingleNode('title').InnerText`（中央社為純文字，同函式一併處理）
- **`teams` 陣列序列化**：PowerShell 函式 `return` 會展開陣列（空→`$null`、單一→純字串），故 `Get-Teams` 的呼叫端一律用 `@(...)` 收，確保 `teams` 永遠序列化成 JSON 陣列（`[]`／`["x"]`／`["x","y"]`）。前端 `newsItemTeams()` 仍做容錯（吃 array／string／null／`{}`），以防舊部署資料

## data/news.json 格式

```json
{
  "updated": "2026-07-14T18:15:10+08:00",
  "count": 3,
  "items": [
    {
      "title": "亞運棒球》統一獅支援2人最多 台灣隊教頭很感謝",
      "url": "https://sports.ltn.com.tw/news/breakingnews/5505031",
      "source": "自由時報",
      "pubDate": "2026-07-14T16:50:19+08:00",
      "teams": ["統一7-ELEVEn獅"]
    }
  ]
}
```

## 前端

- Nav tab「新聞」（在「賽程」與「我的」之間），`data-view="news"`，URL hash `#news`
- 與「我的」共用 `switchView()`（三視圖 main／my／news 互斥）
- `renderNewsView()`：載入 news.json、依 `pubDate` 新到舊、依 Asia/Taipei 日曆日分組（`Intl.DateTimeFormat`，跨時區觀看仍顯示台灣時間）
- 每列：時間（HH:mm）＋標題（連結）＋來源 pill
- 安全：標題／來源走 `escapeHtml()`；連結僅接受 `^https?://`（擋 `javascript:` 注入）
- 空狀態：📰 +「目前沒有相關新聞，稍後再回來看看」（完全無資料時**隱藏篩選卡**）

### 篩選卡（收合式，2026-07-21 上線）

- **收合式**：預設收合，收合列 always visible，顯示「篩選」＋目前條件摘要＋筆數＋展開箭頭；套用篩選後收合仍看得出條件（如「中信兄弟、味全龍 · 本週」）。
- **球隊**：6 隊 `.chip.chip-opp` logo+隊名多選（沿用賽程頁對手 chip 樣式與 `getTeamColor` 隊色），**預設全選**。全選＝顯示全部（含 `teams` 為 `[]` 的綜合新聞）；取消部分後只顯示命中已選隊的新聞（此時無隊標記的綜合新聞不顯示）；全部取消＝0 則、摘要「未選球隊」。
- **時間範圍**：`全部／本週／今天` 膠囊 segmented（依台北日曆日；本週＝近 7 天）。
- **關鍵字**：即時比對標題（`String.includes`）。
- 三條件可疊加；`重設`回到預設（全選／全部／無關鍵字）。
- 狀態為 runtime 記憶體（不寫入 localStorage），切走再回新聞頁會重置為預設。
- 渲染拆為 `renderNewsView()`（載入＋一次性建篩選 UI＋attribution）與 `renderNewsList()`（每次篩選重繪清單＋收合列摘要/筆數）。

## 已知限制 / 未來可加

- 多來源（自由時報／中央社／ETtoday）時同一則新聞可能重複（不同媒體各自報導），去重僅依 URL，不做跨媒體語意去重。
- 球隊標記只看標題，故只在標題出現球員名（未帶隊名）的新聞會漏標、僅在全選時可見（title-only 的固有取捨，見「球隊標記」）。若日後要提高召回，可加球員→球隊對照表，但維護成本高、易過期。
- 時間範圍目前為 `全部／本週／今天`；如需「昨天／近三天」等可再擴充 `#news-timeseg`。
