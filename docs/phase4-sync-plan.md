 喔# Phase 4 跨裝置同步 — 實作計畫

> 撰寫於 2026-04-28，**未實作、未開分支**。供 review 後再決定是否動工。

[engagement.md](engagement.md) Phase 4 的具體實作 plan。

---

## 為什麼跳過 4-A 過渡方案

Phase 4 原本拆兩階段：

- **4-A 過渡方案**：「我的」tab 加「匯出 / 匯入 JSON」按鈕，使用者手動搬檔案
- **4-B 正式版**：CF Workers + KV + Magic Link 登入，背景自動同步

跟 user 對齊使用情境：**手機 + 電腦並行使用，期望每天 sync**。4-A 的手動匯出匯入體驗對「每日 sync」來說太笨拙（每次打卡完都要寄信給自己 / 貼 LINE），所以**直接做 4-B**，不浪費時間在過渡方案。

4-A 仍可作為 4-B 上線後的「離線備份 / 換機遷移」次要功能保留，工時加 0.5 天。

---

## 高層架構

```
[手機 / 電腦瀏覽器]
        ↓ HTTPS
[Cloudflare Worker]
   ├─→ [Cloudflare KV]      使用者資料 store
   └─→ [Resend API]         寄 Magic Link email
```

- 前端：現有 `index.html` 加登入 UI、sync 觸發點、衝突解決邏輯
- 後端：Cloudflare Worker（單檔 JS / TS）處理 auth + KV CRUD
- 儲存：Cloudflare KV（key-value，免費 tier 100K reads/day, 1K writes/day）
- Auth：Magic Link（email 收一次性連結 → click → 拿 session token）

---

## 7 個關鍵決策

### 1. 登入方式 — **Magic Link**

| 選項 | 優點 | 缺點 |
|------|------|------|
| **Magic Link** ✅ | 無密碼、UX 簡潔、所有人都有 email | 收信延遲（通常 < 30 秒） |
| GitHub OAuth | 即時、技術簡單 | 強制使用者要有 GitHub 帳號 |

理由：CPBL 球迷不一定有 GitHub。Magic Link 最普及。

### 2. 後端 — **Cloudflare Workers + KV**

- 個人資料量（profile + favorites + checkins + lastFilter + shownMilestones）一個賽季最多 50 KB
- 完全在 KV 免費額度內：100K reads / 1K writes per day（個人用幾百 reads 已經誇張）
- 不需要 D1（SQL）— 個人資料不做關聯查詢、不做 join

**注意**：本機自動更新比分時試過 CF Workers 失敗，但那是因為 **CPBL API 地理封鎖非台灣 IP**（見 [scoreupdate-history.md](scoreupdate-history.md)）。**使用者同步資料沒有 geofencing 問題**，CF Workers 可行。

### 3. Email 服務 — **Resend**

| 選項 | 免費額度 | 備註 |
|------|---------|------|
| **Resend** ✅ | 3000 封/月、100 封/天 | API 最簡潔，需綁 domain |
| Postmark | 100 封/月（過渡方案） | 可不綁 domain |
| SendGrid | 100 封/天 | UI 較複雜 |

3000/月對個人專案綽綽有餘（一個 active user 一個月不會發超過 30 個 magic link）。

需綁 `trident-tech.com`（你的 domain）做 SPF/DKIM 驗證。

### 4. 衝突解決 — **last-write-wins + 時間戳**

**為什麼不需要 CRDT 或更複雜的合併**：

每筆資料的 key 是 `sno`（場次 ID），不同 sno 之間互不衝突（自然合併）。**唯一的衝突情境**：同一個 sno 在兩台裝置同時編輯。

**處理規則**：
- 每筆 checkin 加 `updatedAt` timestamp（已存在於 schema）
- Push 時 server 比對 `updatedAt`，舊的覆蓋新的就拒絕（回 409 Conflict）
- 客戶端收到 409 就 pull 最新版、重試

**邊界情境**：兩台裝置完全離線編輯同 sno，再上線時雙方都會被對方拒絕一次，最後晚 push 的勝出。可接受。

### 5. 同步時機 — **save 後 push + 開站時 pull**

不做 polling，避免浪費請求 + 電池：

- **開站 / 重新整理時**：fetch 全狀態（一次 read）
- **每次 save（打卡 / 收藏 / 主隊設定 / 篩選變更）**：push 該筆變更（一次 write）
- **手動「同步」按鈕**：使用者主動觸發（防止 sync 卡住）

預估每天個人 read 數：< 10；write 數：< 30。遠低於 KV 額度。

### 6. 加密 — **HTTPS 傳輸 + KV 靜態加密**

- HTTPS：CF Workers 預設啟用
- KV 靜態加密：CF 自己做了
- **不做端對端加密**：複雜度爆炸（需要使用者管 key），且這種資料（看球紀錄、收藏）不算敏感

GDPR / 個資相關：
- 提供「下載我所有資料」按鈕（匯出 JSON，剛好就是 4-A 復用）
- 提供「刪除我所有資料」按鈕（一鍵清空 KV + 帳號）
- 隱私政策文案：明確列出收哪些欄位、不分享給第三方

### 7. 開放範圍 — **先 email 白名單**

| 模式 | 工時 | 風險 |
|------|------|------|
| **白名單**（只你自己 + 朋友 email）✅ | 1 行 | 低 |
| 對外開放任意 email | +2-3 天 | 隱私政策 / 條款撰寫 / 濫用防護 / 退訂機制 |

第一版只白名單，驗證 sync 系統穩定後再對外。對外開放是另一個專案（涉及法律 / 客服 / 抖內機制 / 服務條款），不該夾在 Phase 4 做完。

---

## 工時拆分

| 階段 | 工時 | 內容 |
|------|------|------|
| 1. CF Worker scaffold + KV schema | 1 天 | 寫 Worker / KV 設計 / 部署 pipeline |
| 2. Magic Link auth + Resend 整合 | 2-3 天 | 寄信 / token 驗證 / session cookie |
| 3. Frontend 登入 UI + sync 觸發點 | 2 天 | 登入 modal / sync 邏輯接到 saveUserState / pull on load |
| 4. 衝突處理 + 離線 queue | 2 天 | 409 重試 / 離線時暫存 push / 上線時 flush |
| 5. 隱私文案 + 一鍵刪除 + 測試 | 1-2 天 | UI 文案 / 真機跨裝置驗證 / KV / Resend / token expiry edge cases |
| **合計** | **8-10 天** | 約 1.5-2 週 |

---

## 中間版本（6-7 天）— 目前選定方向

對應使用情境（並行使用 + 球場現場 / 通勤打卡）優化：保留離線 queue（必要），暫緩衝突 409 與完整隱私文案。

### 包含
- ✅ Magic Link auth（2-3 天）
- ✅ 全狀態 push / pull（1 天）
- ✅ 離線 queue（2 天）— 球場 / 通勤離線高風險區仍能打卡，恢復連線後自動 push
- ✅ 白名單（含在 auth 裡）

### 暫緩
- ❌ 衝突 409 重試 — 改純 last-write-wins，雙裝置同時改同一筆會默默覆蓋（後寫的勝出）
- ❌ 完整隱私文案 / 一鍵刪除 — README 註明先頂著，有需求再做

### 之後補回的成本
- 補 409 重試：+ 2 天（含 UI 衝突警告 modal）
- 補隱私 / 一鍵刪除：+ 1-2 天
- 對外開放（白名單放寬）：+ 2-3 天（隱私政策 / 條款 / 退訂）

### 風險自覺
- 雙裝置同時編輯同一場打卡心得 / 評分 → 後寫的覆蓋，先寫的默默消失
  - 機率：個人單人雙裝置使用情境下，**同一場同步編輯**機率低；偶爾發生時資料量小可手動補
  - 緩解：使用習慣上，「填心得」這種長文字盡量在同一台裝置完成不要跨機，可大幅降低衝突

---

## 開工前要先 ready 的事

| # | 項目 | 狀態 |
|---|------|------|
| 1 | Cloudflare 帳號（CF Workers + KV） | 需確認 |
| 2 | Resend 帳號（綁 trident-tech.com domain） | 需確認 |
| 3 | DNS 設定（SPF / DKIM 給 Resend） | 需確認 |
| 4 | 部署 domain（要不要用子網域 `api.trident-tech.com`？或 `cpbl-planner-api.workers.dev`？） | 待定 |

---

## Schema 設計初稿

### Cloudflare KV

```
key: user:{email_hash}
value: {
  email,
  createdAt,
  lastSyncAt,
  state: { ...userState v2 }   // 沿用既有 schema
}
```

或拆成兩個 key：

```
key: user:{email_hash}:profile  → email, createdAt, lastSyncAt
key: user:{email_hash}:state    → userState v2
```

第二種讀寫更細，但個人資料量小，第一種就好。

### Magic Link token

```
key: token:{uuid}
value: { email, createdAt, used: false }
TTL: 15 分鐘（Cloudflare KV 內建 TTL）
```

### Session cookie

JWT in HttpOnly cookie，內容 `{ email, exp }`，TTL 30 天，伺服器端用 Worker secret 簽。

---

## 不在這個 Phase 做的事

- 公開個人頁（Phase 5）
- 球員追蹤、對戰歷史（Phase 6）
- 即時通知（Phase 3 PWA）
- 抖內 / 付費功能 — 不在 roadmap

---

## 風險清單

| 風險 | 機率 | 緩解 |
|------|------|------|
| Resend 免費額度被濫用打爆 | 低（有白名單）| Worker 加 rate limit / IP 限制 |
| 使用者忘記登入 email | 中 | 「重寄 magic link」UI + 保留 schema 讓使用者匯出 localStorage 過渡 |
| CF Worker / KV 服務中斷 | 低 | 客戶端有 localStorage 副本，sync 失敗不影響本機使用 |
| Resend domain 驗證沒過 | 中 | 過渡方案先用 Resend 預設 sandbox domain（限制收件 = 自己） |
| Schema 升版要遷移 | 中 | 沿用既有 `migrateUserState()` 模式，server 端只存 raw state，遷移在客戶端做 |

---

## 下一步

需要 user 回答後再開工：

1. **第 7 項開放範圍**：白名單只你自己用？或開放給朋友（誰）？
2. **CF + Resend 帳號 + DNS 設定**：你準備好了嗎？沒有的話我可以列前置 checklist
3. **要不要先做 1 day POC**（打卡 push 到 mock endpoint，純驗證前端 sync 邏輯架構）— 還是直接接真 CF Worker

回完這 3 題，我開分支寫具體 step-by-step plan。

> **版本選擇已定**：中間版 6-7 天（保留離線 queue，暫緩 409 衝突 / 完整隱私文案）。
