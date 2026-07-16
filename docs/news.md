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

## 資料來源

| 來源 | RSS 端點 | 狀態 |
|------|---------|------|
| 自由時報 體育 | `https://news.ltn.com.tw/rss/sports.xml` | 使用中（feed 無限制條款，UTF-8 正規 XML） |

未來要加來源：先確認該媒體 RSS 無限制條款，再加進 `scripts/fetch-news.ps1` 的 `$Feeds` 陣列即可（含 `name` 與 `url`）。

## 過濾邏輯

自由時報體育 RSS 涵蓋所有運動（世足／NBA／網球…），需過濾出中職相關。

- 條件：標題或 RSS 導言（description，**不儲存**，僅用於判斷相關性）符合 `$CpblRegex`
- `$CpblRegex = 中職|中華職棒|職棒|中信兄弟|樂天桃猿|富邦悍將|統一7|統一獅|味全龍|台鋼雄鷹`
- **只用全名**（中信兄弟…）不用裸短名（統一／富邦／樂天），避免撞到其他組織或他項運動球隊（例：富邦勇士是籃球）
- 範圍決策（2026-07-14）：**審中職相關即可**——含亞運／旅外／選秀等球迷關心的廣義棒球新聞都收，不限縮到聯盟賽事本身

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
- **CDATA 取值**：LTN feed 的 title/description 是 CDATA，`$item.title` 會回傳 XmlElement，須用 `SelectSingleNode('title').InnerText`

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
      "pubDate": "2026-07-14T16:50:19+08:00"
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
- 空狀態：📰 +「目前沒有相關新聞，稍後再回來看看」

## 已知限制 / 未來可加

- 目前單一來源（自由時報）。多來源時同一則新聞可能重複（不同媒體各自報導），去重僅依 URL，不做跨媒體語意去重。
- 未做球隊篩選／關鍵字搜尋（依使用者決策僅需「照時間排序」）。若日後要加，team 欄位可在 `fetch-news.ps1` 依 `$CpblRegex` 命中隊名時標記。
