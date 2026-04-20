# 比分自動更新方案評估

現行方案：**方案 D（本機 Windows 工作排程器）**。境外 serverless（Cloudflare Worker、Google Apps Script、fly.io 等）都被 CPBL IP 封鎖，已全數驗證失敗。歷史記錄與失敗細節見 [scoreupdate-history.md](scoreupdate-history.md)。

---

## 🔖 進度記錄

### 2026-04-20 — Task Scheduler 錯過補跑 + 賽事簡報

- Task Scheduler 04/18~04/20 連續 3 天未執行（週末電腦關機 + 週一 09:00 還沒開機），手動跑 `update-scores.bat` 補上，commit `d18f33e`
- 用 `Set-ScheduledTask -Settings.StartWhenAvailable = $true` 讓下次錯過排程時開機後自動補跑
- 卡片加入「📋 簡報」pill 顯示 CPBL 賽事簡報（連勝連敗、里程碑），commit `3fec3c0`。詳見 [briefings.md](briefings.md)

### 2026-04-15 之前 — 方案 D 上線

- [scripts/update-scores.ps1](../scripts/update-scores.ps1) PowerShell 版抓取腳本（取代 bash + node）
- [scripts/update-scores.bat](../scripts/update-scores.bat) Task Scheduler 包裝 bat（ASCII 純淨版）
- Git 認證已設，Task Scheduler 2026-04-14 10:52 首次自動執行成功
- 移除網頁「🔄 更新比分」按鈕（commit `6871437`）：CORS proxy / CF Worker / GAS 皆失敗，比分改由本機排程更新

## 🔧 已解決的問題

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

2026-04-20 做賽事簡報功能時踩到的坑，記下以免重犯：

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
- [briefings.md](briefings.md) — 賽事簡報功能（由同一支腳本維護）
- [scoreupdate-history.md](scoreupdate-history.md) — 歷史失敗方案（CF Worker、GAS 等）
