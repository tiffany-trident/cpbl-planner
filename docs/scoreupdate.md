# 比分自動更新方案評估

現行方案：**方案 D（本機 Windows 工作排程器）**。境外 serverless（Cloudflare Worker、Google Apps Script、fly.io 等）都被 CPBL IP 封鎖，已全數驗證失敗。歷史記錄與失敗細節見 [scoreupdate-history.md](scoreupdate-history.md)。

---

## 🔖 進度記錄

### 2026-06-22 — CPBL API 改 HiNet CDN cookie 挑戰 + push 韌性補強

- **問題**：戰績表停在 6/16。三層根因疊在一起：
  1. 6/18 00:13 那次 commit 成功但 `git push` 當下連不上 github.com（剛 wake-from-sleep 網路未就緒），commit 卡本機沒上 origin。
  2. 筆電 6/18 11:52 ~ 6/22 10:58 連睡 4 天，排程完全沒跑（`NumberOfMissedRuns=54`、`LastTaskResult=0x41306`）。
  3. **致命**：CPBL API `POST /schedule/getgamedatas` 現在被 **HiNet CDN** 用 cookie 挑戰擋住 — 第一次 POST 回 `308 Permanent Redirect`（Location 指回同一 URL）+ `Set-Cookie: __chtcdn=...`，要帶這個 cookie 重打才會過。PS 5.1 `Invoke-WebRequest` 對 POST 不會自動跟 308（直接 throw），所以 fetch 整個壞掉，之後每次跑都失敗。
- **診斷關鍵**：`curl -i -X POST` 看到 `Server: HiNetCDN` + 308 + `Set-Cookie: __chtcdn`；帶 cookie 重打 308→500（CDN 那關已過，500 只是少 token）。
- **修正**：
  - `update-scores.ps1`：API POST 包成 retry 迴圈，`-MaximumRedirection 0` 抓 308，從回應 `Set-Cookie` 取出 `__chtcdn` 加進 WebSession 後重打（最多 3 次）。實測一次重試即過、抓回 378 場 + 補 6/18~6/21 共 12 筆 briefing。
  - `update-scores.bat`：commit 與 push 拆開，**改成每次都 `git push`**（origin 已最新時為 no-op exit 0）。任何一次 push 失敗留下的 pending commit，下個整點 retry 即使「無新資料」也會自動補送，不再卡到下次剛好有新賽事。
- **副註**：HiNet CDN 挑戰是新行為（6/18 還正常）。若日後 cookie 名稱或機制再變，先用 `curl -i -X POST` 看 CDN 回應標頭。

### 2026-06-01 — 筆電 sleep 才是真因，加 hourly retry trigger

- **問題**：2026-05-23 ~ 05-29 連續 7 天 `NumberOfMissedRuns`，5/30 又 miss 一次。`LastBootUpTime` 顯示電腦沒重啟、手動 `Start-ScheduledTask` 完全正常，排除密碼/權限/網路/腳本。
- **真因**：筆電進入 Modern Standby (S0) 期間 task scheduler 也睡，task `WakeToRun=False` 不會主動喚醒電腦。`Get-WinEvent Power-Troubleshooter` 顯示 5/22 09:13 → 5/29 10:55 sleep 整整 7 天、5/29 16:10 → 5/30 16:36 sleep 24h，**時間軸完美吻合 missed runs**。`StartWhenAvailable=$true` 對「sleep 醒來補跑」邏輯也不可靠 — 它只在下次喚醒/開機時補跑**最近一次** miss。
- **走錯一步**（2026-05-29）：誤推測「`LogonType: Password` 在 lock screen 下吞 trigger」，把 principal 改成 `Interactive`。5/30 又 miss 才知道方向錯了 — 從 5/22 之前 6 週 Password 模式都跑得好好的就該想到根因不在這。改動本身無害，保留 Interactive（順便驗證該模式下 git push 可讀 Credential Manager）。
- **修正**：加 hourly retry trigger — daily 09:00 觸發後每 1 小時 repeat，duration 13 小時（覆蓋 09:00 ~ 22:00 共 14 次/天）。筆電隨時從 sleep 醒來，下個整點 trigger 就 catch 到。
  ```powershell
  $trigger = New-ScheduledTaskTrigger -Daily -At '09:00:00'
  $rep = (New-ScheduledTaskTrigger -Once -At '09:00' `
            -RepetitionInterval (New-TimeSpan -Hours 1) `
            -RepetitionDuration (New-TimeSpan -Hours 13)).Repetition
  $trigger.Repetition = $rep
  Set-ScheduledTask -TaskName 'CPBL 比分自動更新' -Trigger $trigger  # 需 RunAs admin
  ```
- **驗證**：2026-06-01 上午筆電從 sleep 醒來 11 分鐘內 11:00 trigger 自動觸發，補上 5/22 ~ 5/31 累積 9 條 briefings，commit `29ece72` push 成功。
- **副作用評估**：每小時切 main 分支不擾人 — bat 有 dirty check（tracked dirty → abort）保護編輯中的工作，沒新資料就 no changes。但**編輯中的 tracked 改動會擋住 task 跑**，要記得 commit 或 stash。
- **診斷血淚**：「task 沒跑但手動觸發 OK」第一個該查的不是 logon type，是 `powercfg /a` + Power-Troubleshooter event log 看筆電有沒有 sleep 跨過排程時間。`LastBootUpTime` 只看上次從關機開機，看不出中間 sleep 多少次。

### 2026-04-23 — Task Scheduler 推錯分支 + 分支守衛

- **問題**：Phase 1 開發期 Task Scheduler 在 `feat/phase1-personalization` 分支上執行，bat 不檢查當前分支，ps1 commit + push 跑到 feature 分支（`a7cb143`），線上版（從 main 部署）當天沒拿到更新。Phase 1 merge 回 main 時才把這次 auto-update 一併帶進來。
- **修正**（commit `7c7645e`、`8d94d16`）：`update-scores.bat` 加入分支守衛
  - 記住原分支、檢查 working tree 是否乾淨（tracked files dirty → abort，**不自動 stash**，避免遺失使用者進行中的工作，由人工處理）
  - 若不在 main 則 `git checkout main && git pull`，執行完再切回原分支
  - 切回前 `git checkout -- index.html cpbl-planner.html data/briefings.json` 清掉 ps1 寫入的 line-ending 殘留（PowerShell `` `n `` 是 LF，Windows Git autocrlf 會認為 working tree 有差異；不清會讓下次 dirty check abort）
- **測試方法**：在 test branch 上跑兩輪 `update-scores.bat`，驗證切換邏輯 + working tree 最終乾淨

### 2026-04-20 — Task Scheduler 錯過補跑 + 賽事記錄

- Task Scheduler 04/18~04/20 連續 3 天未執行（週末電腦關機 + 週一 09:00 還沒開機），手動跑 `update-scores.bat` 補上，commit `d18f33e`
- 用 `Set-ScheduledTask -Settings.StartWhenAvailable = $true` 讓下次錯過排程時開機後自動補跑
- 卡片加入「📋 賽事記錄」pill 顯示 CPBL 賽事記錄（連勝連敗、里程碑），commit `3fec3c0`。詳見 [briefings.md](briefings.md)

### 2026-04-15 之前 — 方案 D 上線

- [scripts/update-scores.ps1](../scripts/update-scores.ps1) PowerShell 版抓取腳本（取代 bash + node）
- [scripts/update-scores.bat](../scripts/update-scores.bat) Task Scheduler 包裝 bat（ASCII 純淨版）
- Git 認證已設，Task Scheduler 2026-04-14 10:52 首次自動執行成功
- 移除網頁「🔄 更新比分」按鈕（commit `6871437`）：CORS proxy / CF Worker / GAS 皆失敗，比分改由本機排程更新

## 🔧 已解決的問題

**筆電 sleep 跨過排程，task 完全沒跑（2026-05-22 ~ 06-01）**
- 現象：連續多天 `NumberOfMissedRuns`，但 `LastBootUpTime` 顯示電腦沒重啟、手動 `Start-ScheduledTask` 跑得起來
- 原因：Win11 Modern Standby (S0) 期間 task scheduler 也休眠，`WakeToRun=False` 不喚醒電腦；`StartWhenAvailable` 的補跑機制對 sleep wake 不可靠
- 診斷關鍵：`powercfg /a` 看睡眠能力、`Get-WinEvent -ProviderName Microsoft-Windows-Power-Troubleshooter` 看實際 sleep/wake 時間軸，跟 missed runs 時間對得起來才確認
- 修正：加 hourly retry trigger（daily 09:00 + Repetition PT1H / PT13H，覆蓋 09:00 ~ 22:00）
- 副註：曾誤推測 `LogonType: Password` 在 lock screen 吞 trigger，改 Interactive 後仍 miss — 方向錯。改動保留無害

**Task Scheduler 在 feature 分支上推錯分支（2026-04-23）**
- 現象：排程正常執行，但 push 到當下 working tree 所在的 feature 分支而非 main，線上未更新
- 原因：`update-scores.bat` 不檢查當前分支，直接在哪個分支就 commit 到哪個
- 修正：bat 加入分支守衛（dirty check abort → checkout main + pull → ps1 + commit + push → 清 line-ending 殘留 → 切回原分支），commit `7c7645e`、`8d94d16`

**Task Scheduler 錯過後不會自動補跑（2026-04-20）**
- 現象：04/18、04/19、04/20 連續 3 天沒更新。電腦週末關機 + 週一 09:00 還沒開機
- 修正：`Set-ScheduledTask -Settings.StartWhenAvailable = $true`，開機後自動補跑錯過的排程
- 需系統管理員權限：`Start-Process powershell -Verb RunAs ...`

**瀏覽器快取導致更新看不到（2026-04-15）**
- 腳本 09:00 已更新並 push，但瀏覽器仍載入舊版。強制重新整理（Ctrl+Shift+R）即可

**Task Scheduler `0x80070002` 找不到檔案**
- 原因：路徑含空格（`AI Work\baseball plan`），Task Scheduler 在空格處截斷
- 修正：動作改為 `cmd.exe` + `/c "完整 bat 路徑"`

**網頁資料全部消失（RAW_DATA 格式錯誤）**
- 原因：`,$row | ConvertTo-Json -Compress` 透過管線傳陣列會被包成物件 `{"value":[...],"Count":12}`
- 修正：改用 `ConvertTo-Json -InputObject $row -Compress` 直接傳入，輸出純陣列

## PowerShell 5.1 中文字面陷阱

2026-04-20 做賽事記錄功能時踩到的坑，記下以免重犯：

1. **UTF-8 無 BOM 的 `.ps1` 檔，Chinese 註解會汙染下一行字串字面**
   - 症狀：`$x = '// something'` 結果 `$x` 是空字串，但 length 顯示正常
   - 已知 case：中文註解行 + FullWidth 括號 `（…）` + 下一行接 ASCII 字面 → 字面被吃掉
   - 修法：關鍵字串字面前後用英文註解，或把檔案存成 UTF-8 with BOM
2. **`[regex]::Replace` 大 pattern + lookaround 會卡死（catastrophic backtracking）**
   - `(?:(?!</span>)[\s\S])*?` 這類 tempered greedy token 在特定輸入會指數級回溯
   - 修法：改用純字串操作（IndexOf + LastIndexOf + Substring）
3. **函式定義必須在呼叫之前**
   - PS 5.1 從上到下執行，不像 JS 會 hoist。函式定義放在使用點之前
4. **`$utf8NoBom = New-Object System.Text.UTF8Encoding $false`** 寫 UTF-8 無 BOM；`WriteAllText` 用這個避免 BOM 汙染

## 🔜 待辦

- [ ]（選配）加 `.gitattributes` 消除 LF→CRLF 警告
- [ ]（選配）前端 JS 剝除 briefing 開頭「技術室人員」那行

---

## 方案 D：Windows Task Scheduler（現行）

本機台灣 IP 是唯一能打通 CPBL 的路徑，用 Windows 工作排程器自動化。

### 設定步驟

1. `Win+R` → `taskschd.msc` → 建立基本工作
2. **名稱**：`CPBL 比分自動更新`
3. **觸發**：每天 09:00
4. **動作**：啟動程式
   - 程式：`cmd.exe`
   - 引數：`/c "C:\Trident\AI Work\baseball plan\scripts\update-scores.bat"`
   - 起始位置：`C:\Trident\AI Work\baseball plan`
   - 不要直接指定 `.bat` 為程式，路徑含空格會被截斷
5. 內容對話方塊 → **設定** 分頁：
   - ✅ 如果排程工作開始時間已過，立即啟動工作（`StartWhenAvailable`）
   - ✅ 失敗時每 10 分鐘重試，最多 3 次
   - ✅ 執行超過 1 小時則停止
6. **一般** 分頁 → ✅ 以最高權限執行（避免 git push 權限）

### 前置

- Git for Windows 裝在預設 `C:\Program Files\Git\`，否則改 `update-scores.bat` 前兩行
- `git push` 已設認證（SSH key 或 credential manager）
- 手動 `scripts\update-scores.bat` 跑一次確認能 push，再設排程

### StartWhenAvailable 開關指令

```powershell
$t = Get-ScheduledTask -TaskName 'CPBL 比分自動更新'
$t.Settings.StartWhenAvailable = $true
Set-ScheduledTask -TaskName 'CPBL 比分自動更新' -Settings $t.Settings
```

需管理員權限，若失敗：`Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command',"..."`

---

## 相關檔案

- [scripts/update-scores.ps1](../scripts/update-scores.ps1) — 現行 PowerShell 抓取腳本
- [scripts/update-scores.bat](../scripts/update-scores.bat) — Task Scheduler 包裝 bat
- [logs/update-scores.log](../logs/update-scores.log) — 執行 log
- [briefings.md](briefings.md) — 賽事記錄功能（由同一支腳本維護）
- [scoreupdate-history.md](scoreupdate-history.md) — 歷史失敗方案（CF Worker、GAS 等）
