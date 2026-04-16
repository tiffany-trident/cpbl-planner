# 球場天氣功能規劃

## 資料來源

**Open-Meteo**（首選）
- 免費、不需 API key、支援 CORS，前端直接 fetch
- 逐時預報最長 16 天，本功能只取 7 天
- 精準度來自全球模型，非氣象署本地資料，對看球決策夠用

**備選：CWA 中央氣象署**
- 註冊流程：opendata.cwa.gov.tw → 加入會員 → email 驗證 → 立即取得 API key（免費、免審核）
- 鄉鎮級逐 3 小時預報（2 天）+ 12 小時預報（7 天），台灣最準
- 支援 CORS（`Access-Control-Allow-Origin: *`）
- 如果 Open-Meteo 不夠準再換，架構改動小（換 fetch URL + 解析邏輯）

---

## 資料流

```
頁面載入 → render()（先顯示卡片，無天氣）
         → loadWeather()（非同步）
              ├─ 篩出未來 7 天內、非延賽的場次
              ├─ 收集需要的球場（去重，通常 3~5 個）
              ├─ 檢查 localStorage 快取（TTL 3 小時）
              ├─ 未快取的球場 → Promise.allSettled() 平行 fetch
              └─ 完成後 re-render()，卡片上出現天氣
```

## API 呼叫

每個球場一個 request，只取需要的 3 個欄位：

```
https://api.open-meteo.com/v1/forecast
  ?latitude={lat}&longitude={lon}
  &hourly=temperature_2m,precipitation_probability,weathercode
  &forecast_days=7
  &timezone=Asia/Taipei
```

## 球場經緯度對應

| 球場 | 緯度 | 經度 |
|------|------|------|
| 大巨蛋 | 25.0478 | 121.5318 |
| 天母 | 25.0930 | 121.5200 |
| 新莊 | 25.0110 | 121.4320 |
| 樂天桃園 | 25.0025 | 121.2094 |
| 洲際 | 24.1892 | 120.6537 |
| 嘉義市 | 23.4757 | 120.4400 |
| 亞太主 | 23.1024 | 120.2941 |
| 澄清湖 | 22.6640 | 120.3560 |
| 斗六 | 23.7101 | 120.5407 |
| 花蓮 | 23.9653 | 121.5850 |

## 天氣顯示邏輯

| 時間範圍 | 顯示方式 | 範例 |
|---------|---------|------|
| 未來 72 小時內 | 比賽開打那小時的逐時天氣 | `☀️ 28° · 10%💧` |
| 3~7 天 | 當日白天概況（高低溫 + 最大降雨率） | `⛅ 22-28° · 40%💧` |
| 超過 7 天 / 已完賽 / 延賽 | 不顯示 | — |

## WMO 天氣代碼對應

| 代碼 | 意義 | 圖示 | 中文 |
|------|------|------|------|
| 0 | 晴天 | ☀️ | 晴 |
| 1-3 | 局部多雲 | ⛅ | 多雲 |
| 45, 48 | 霧 | 🌫️ | 霧 |
| 51-55 | 毛毛雨 | 🌦️ | 毛毛雨 |
| 61-65 | 雨 | 🌧️ | 雨 |
| 80-82 | 陣雨 | 🌦️ | 陣雨 |
| 95-99 | 雷雨 | ⛈️ | 雷雨 |

## UI 設計

### 卡片上的位置

放在 card-top 列，時間和球場之間：

```html
<div class="card-top">
  <span class="card-top-time">18:35</span>
  <span class="card-weather">☀️ 28° · 10%💧</span>
  <span class="card-top-venue">◉ 大巨蛋</span>
</div>
```

### 樣式

- 小字 12px、暖米底 `#FFF9F0` 圓角 pill（`border-radius: 10px`）
- 溫度粗體 `#4A3728`
- 降雨率藍色 `#5B7BB4`；≥ 50% 轉紅色 `#C25B5B` 提醒
- 載入中：`⏳ 天氣載入中…`（脈衝動畫）
- API 失敗：不顯示，不影響原有功能
- 手機版：字體縮小到 11px

## 快取策略

- `localStorage` 存每個球場的預報，key 格式：`weather_大巨蛋`
- TTL 3 小時（預報更新頻率約 6 小時）
- localStorage 滿了就只用記憶體快取，不影響功能
- 每個球場資料約 15-20 KB，10 球場合計 ~150-200 KB

## 程式碼結構

全部加在現有 `cpbl-planner.html` 的 `<script>` 內：

1. **常數**：`STADIUM_COORDS`（球場經緯度）、`WMO_WEATHER_MAP`（天氣代碼→圖示）、`WEATHER_CACHE_TTL`
2. **狀態**：`weatherCache`（記憶體快取）、`weatherLoading`（載入旗標）
3. **工具函式**：
   - `getWeatherInfo(code)` — WMO 代碼轉圖示/中文
   - `getGameWeather(game)` — 取得單場比賽的天氣物件
   - `buildWeatherHTML(game)` — 產生卡片天氣 HTML
4. **非同步函式**：
   - `fetchWeatherForStadiums(stadiums)` — 平行 fetch + 快取寫入
   - `loadWeather()` — 主流程：篩場次 → 去重球場 → 檢查快取 → fetch → re-render
5. **修改既有函式**：
   - `render()` — card-top 插入 `buildWeatherHTML(g)`
   - `loadData()` — 最後呼叫 `loadWeather()`

## 防呆處理

- API 逾時 10 秒（`AbortController`）
- 所有 fetch 用 `try/catch`，失敗靜默跳過
- 時區不用轉換（API 和賽程都是 `Asia/Taipei`）
- 同日同球場多場比賽共用同一筆 fetch
- 逐時小時對應：比賽 18:35 → 取 T18:00 的預報

## 待討論

- [ ] 介面呈現細節（天氣放卡片哪個位置、怎麼排版最自然）
- [ ] 降雨率高的場次是否需要額外的視覺提醒（例如卡片背景色）
- [ ] 是否需要點擊展開更詳細的逐時預報
