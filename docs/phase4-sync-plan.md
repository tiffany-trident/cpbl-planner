# Phase 4 跨裝置同步 — 實作計畫

> 撰寫於 2026-04-28，更新於 2026-05-05。
> **POC 已實作於 `feat/phase4-poc-sync-skeleton`**（2026-05-04 跨裝置驗證通過，未 merge main）。
> **4-B 正式版開工於 2026-05-05，分支 `feat/phase4-cf-worker-auth`**。
> ⚠️ **2026-05-05 pivot**：原本選 Magic Link + Resend，改走 **Google OAuth**（user 無 sender domain DNS 寫入權，且 Google OAuth Testing 模式自帶白名單 — 詳見「關鍵決策 #1」）。

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
   ├─→ [Cloudflare KV]            使用者資料 store
   └─→ [Google OAuth endpoints]   登入驗證 + 白名單（Testing 模式 test users）
```

- 前端：現有 `index.html` 加登入 UI、sync 觸發點、衝突解決邏輯
- 後端：Cloudflare Worker（單檔 TS）處理 OAuth callback + KV CRUD
- 儲存：Cloudflare KV（key-value，免費 tier 100K reads/day, 1K writes/day）
- Auth：Google OAuth Authorization Code flow（redirect → consent → callback → session cookie）
- 白名單：Google OAuth consent screen 在 Testing 狀態時，**只有 GCP project 內的 test users 能登入**，0 行 Worker 程式碼

---

## 關鍵決策

### 1. 登入方式 — **Google OAuth**（2026-05-05 pivot）

| 選項 | 優點 | 缺點 |
|------|------|------|
| **Google OAuth** ✅ | 不需 email 服務、台灣 Gmail 普及率 99%+、Testing 模式自帶白名單、無 token / retry / expiry 邏輯要寫 | 朋友需有 Google 帳號（實務上幾乎都有） |
| ~~Magic Link~~ | 任何 email 都能用 | 需 sender domain（user 無 trident-tech.com DNS 寫入權）+ token store / retry / expiry 系統 |
| GitHub OAuth | 即時、技術簡單 | 強制使用者要有 GitHub 帳號（CPBL 球迷不一定有） |

**Pivot 理由**（2026-05-05 重新評估）：原本 doc 只比較 Magic Link vs GitHub OAuth，漏列 Google OAuth。User 確認 trident-tech.com 是公司域名無 DNS 寫入權後，Magic Link 走 Brevo 寄件者觀感差且要寫一堆 token logic；Google OAuth 跳過所有 email 麻煩，且 **Google OAuth Testing 模式最多 100 個 test users 就是內建白名單**，不用 Worker hard-code email list。

**白名單管理**：加減朋友 = 在 GCP console 「Audience → Test users」加減 email，不改 Worker 程式碼。

### 2. 後端 — **Cloudflare Workers + KV**

- 個人資料量（profile + favorites + checkins + lastFilter + shownMilestones）一個賽季最多 50 KB
- 完全在 KV 免費額度內：100K reads / 1K writes per day（個人用幾百 reads 已經誇張）
- 不需要 D1（SQL）— 個人資料不做關聯查詢、不做 join

**注意**：本機自動更新比分時試過 CF Workers 失敗，但那是因為 **CPBL API 地理封鎖非台灣 IP**（見 [scoreupdate-history.md](scoreupdate-history.md)）。**使用者同步資料沒有 geofencing 問題**，CF Workers 可行。

### 3. Email 服務 — **不需要**（2026-05-05 pivot 後刪除）

原本選 Resend，但 Google OAuth 不寄 email，整段刪除。
- 工時節省：原 Magic Link auth + Resend 整合 2-3 天 → Google OAuth callback 約 1 天
- 設定省略：sender domain 決策、SPF / DKIM 設定、Resend 帳號全部不需要

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
| 2. Google OAuth callback + session cookie | 1 天 | OAuth redirect / token exchange / 簽 JWT cookie |
| 3. Frontend 登入 UI + sync 觸發點 | 1-2 天 | 登入 modal / `httpSyncBackend` 接到 POC sync layer / pull on load |
| 4. 衝突處理 + 離線 queue | 2 天 | 409 重試 / 離線 queue 已在 POC，正式版加 timestamp 比對 |
| 5. 隱私文案 + 一鍵刪除 + 測試 | 1-2 天 | UI 文案 / 真機跨裝置驗證 / KV / token expiry edge cases |
| **合計** | **6-8 天** | 約 1-1.5 週（比原估省 2 天，省在跳過 Magic Link / Resend） |

---

## 中間版本（6-7 天）— 目前選定方向

對應使用情境（並行使用 + 球場現場 / 通勤打卡）優化：保留離線 queue（必要），暫緩衝突 409 與完整隱私文案。

### 包含
- ✅ Google OAuth callback（1 天）
- ✅ 全狀態 push / pull（1 天，POC 已驗證架構）
- ✅ 離線 queue（POC 已實作，正式版只需把 mock backend 換 http）
- ✅ 白名單（GCP Testing test users，0 行 Worker code）

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

## 開工前要先 ready 的事（2026-05-05 全部就緒）

| # | 項目 | 狀態 |
|---|------|------|
| 1 | Cloudflare 帳號（CF Workers + KV） | ✅ Tiffany@trident-tech.com，subdomain `tiffany-434.workers.dev` |
| 2 | ~~Resend 帳號~~ | ❌ 不需要（Google OAuth pivot 後刪除） |
| 3 | ~~DNS / SPF / DKIM~~ | ❌ 不需要 |
| 4 | Worker 部署 domain | ✅ `cpbl-planner-api.tiffany-434.workers.dev` |
| 5 | GCP project + OAuth client | ✅ Project `CPBL planner`、Client ID `154138452880-o245n9ejknhboe84u0ujb9uvqtqi4hc2.apps.googleusercontent.com`、scopes openid/email/profile、Tiffany 為唯一 test user |
| 6 | Authorized redirect URIs | ✅ `http://localhost:8787/auth/callback` + `https://cpbl-planner-api.tiffany-434.workers.dev/auth/callback` |
| 7 | Client Secret | ⬜ 已產生，等 Worker 骨架就緒後 user 用 `wrangler secret put GOOGLE_CLIENT_SECRET` 設入 |

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

### OAuth state（防 CSRF）

```
key: oauth_state:{random_string}
value: { createdAt, redirectAfterLogin? }
TTL: 10 分鐘（Cloudflare KV 內建 TTL）
```

OAuth flow 開始時 Worker 產生 random `state`，存 KV + 帶進 Google authorize URL；callback 收到後驗證 state 存在才繼續。

### Session cookie

JWT in HttpOnly cookie，內容 `{ email, sub, exp }`（`sub` 是 Google 使用者 ID，`email` 來自 Google userinfo），TTL 30 天，伺服器端用 Worker secret（`SESSION_SIGNING_KEY`）簽。

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
| 朋友拒用 Google 登入 | 低 | 白名單朋友幾乎都有 Gmail；極端 case 加 GitHub OAuth fallback（不在 v1） |
| Google OAuth Testing 模式 100 人上限 | 低 | 個人專案 0 行銷壓力，超過 100 朋友等同準備好 PUBLISH，是好問題不是風險 |
| CF Worker / KV 服務中斷 | 低 | 客戶端有 localStorage 副本，sync 失敗不影響本機使用 |
| OAuth Client Secret 外洩 | 低 | `wrangler secret put` 不入 git；如外洩 Google console 重發 secret 即可 |
| Schema 升版要遷移 | 中 | 沿用既有 `migrateUserState()` 模式，server 端只存 raw state，遷移在客戶端做 |

---

## User 回覆紀錄

### 2026-05-04
| # | 問題 | 回覆 |
|---|------|------|
| 1 | 白名單範圍 | 自己 + 少數朋友（具體 email 名單待收齊） |
| 2 | CF + Resend + DNS 是否就緒 | 未準備，需走前置 checklist |
| 3 | 是否先做 POC | 先做 — 已完成 |

### 2026-05-05（pivot 日）
| # | 決議 | 回覆 |
|---|------|------|
| 1 | trident-tech.com DNS 寫入權 | 沒有 → Magic Link 方案受阻 |
| 2 | 改走 Google OAuth | ✅ 接受（user 原本也想，是我框架引導錯方向） |
| 3 | Worker 名字 `cpbl-planner-api` | ✅ |
| 4 | 白名單先只自己（Google Testing 模式） | ✅ |
| 5 | 開分支 `feat/phase4-cf-worker-auth` | ✅ |

> **版本選擇已定**：中間版 6-8 天（保留離線 queue，暫緩 409 衝突 / 完整隱私文案）。

---

## POC 結論（2026-05-04）

**分支**：`feat/phase4-poc-sync-skeleton`（不 merge main，純驗證架構）

### 確認 OK 的 hook 點

- **`saveUserState(state)`**：拆出 `writeUserStateLocal()` 純本機寫，外層 `saveUserState` 在本機寫成功後 fire-and-forget 觸發 `syncPush(state)`。8 個既有 callsite（toggleFavorite / saveCheckinForm / setMainTeam / 篩選記憶 / 里程碑等）完全不用改，自動取得 sync 能力。
- **App 開站**：在 `loadData()` + `initMyViewFromHash()` 之後串 `syncFlushQueue().then(syncPull)`，順序穩定無 race。
- **`syncPull` 遠端空時 seed 邏輯**：第一次跑時遠端是空的，若本機有資料（`mainTeam` / `checkins` / `favorites` 任一非空）就 push 上去當 source-of-truth seed；否則保留遠端空，避免新裝置誤覆蓋舊裝置。**這個 seed rule 必須保留到正式版**。

### 抽象界面設計（正式版直接復用）

```js
const syncBackend = {
  async push(state) { ... },
  async pull() { ... return remote || null; }
};
```

正式版只需把 `mockSyncBackend` 換成 `httpSyncBackend`（fetch CF Worker），上層 `syncPush` / `syncPull` / `syncFlushQueue` / 離線 queue 全部不動。

### 本機跨「裝置」測試方案

`?device=A|B` URL 後綴 → `USER_STORE_KEY = 'cpbl_planner_v1' + suffix`，三個分頁可同時模擬「預設 / A / B」三裝置共享同一 mock backend。驗證流程：

1. 預設裝置開站 → seed push（mock backend 從空變有）
2. 切到 `?device=A` → A 本機空 → 自動 pull → 套上預設的資料 ✅
3. （仍可測：在 A 改東西 → 切到 B → B pull 到 A 的最新狀態）

### POC 範圍外 / 正式版要補的

- ❌ **Last-write-wins 比對**：POC 採「遠端有資料就一律覆蓋本地」，正式版要比對 `updatedAt` timestamp，本地較新才不被覆蓋
- ❌ **同步 UI 位置**：POC 放「我的」tab footer（dev/debug 用），正式版要搬到 nav 列讓所有 view 都看得到
- ❌ **POC 偵錯選項**（模擬離線 toggle / device 切換連結）：正式版拿掉
- ❌ **真正的 auth 流程**：POC 假設單一使用者，沒有 Magic Link

---

## 4-B 實作切片（incremental）

| # | 切片 | 範圍 | 狀態 |
|---|------|------|------|
| 1 | Worker scaffold | `cloudflare-worker/` 目錄 + `wrangler.toml` + `package.json` + `src/index.ts`（只有 `/healthz`）| 🟡 進行中（2026-05-05）|
| 2 | KV namespace 綁定 | `wrangler kv:namespace create CPBL_USER_STORE` + 綁進 `wrangler.toml` | ⬜ |
| 3 | OAuth callback | `/auth/login`（redirect to Google）+ `/auth/callback`（驗 state、token exchange、簽 JWT cookie）| ⬜ |
| 4 | Push / Pull endpoints | `/state` GET / PUT，session cookie 驗 → 從 sub 推 KV key → CRUD | ⬜ |
| 5 | 前端 `httpSyncBackend` | drop-in 取代 POC 的 `mockSyncBackend`、加 401 → 跳登入 modal | ⬜ |
| 6 | 登入 modal UI | 設定主隊頁旁加「跨裝置同步」入口 | ⬜ |
| 7 | 移除 POC debug UI | 拿掉模擬離線 toggle、device 切換連結；sync 狀態 pill 搬到 nav | ⬜ |
| 8 | timestamp 比對 | 加 `lastSyncAt` 與 server `updatedAt` 比對，本地較新就拒絕被覆蓋 | ⬜ |

每切片獨立可部署 / 可驗證。完整流程跑通後再 merge main。
