# Box 檢視頁（單場戰績表）

點「已完賽」賽程卡片本體 → 開啟全螢幕 box 頁（hash 路由 `#box=NNN`），顯示該場逐局比分、打擊、投手、比賽資訊與賽事記錄。

## 資料來源

沿用賽事記錄的 `POST /box/getlive`（見 [briefings.md](briefings.md)），**同一次呼叫**同時取 briefing 與 box，不增加對 CPBL 的請求數。回傳裡用到的欄位：

| 區塊 | 來源欄位 |
|------|---------|
| 逐局比分 | `ScoreboardJson`（每隊每局一列，含 ScoreCnt/HittingCnt/ErrorCnt，加總得 R/H/E） |
| 打線（棒次＋守位＋代打） | `FirstSnoJson`（`Lineup` 棒次、`DefendStation` 守位代碼、`PinchHitterRunner` 代打/代跑、`MainEventNoS` 進場事件） |
| 打擊數據 | `BattingJson`（以 `HitterAcnt` 為 key join 到打線） |
| 投手 | `PitchingJson`（陣列順序＝登板順序） |
| 比賽資訊 | `CurtGameDetailJson`（球場/觀眾/時間/天氣/裁判/勝敗救/MVP） |

## 存放：每場一檔

`data/box/NNN.json`（3 位零填 sno）。前端點某場才 fetch 該檔（同源、約 5KB），不需下載全季。抓取增量判斷＝該檔是否已存在。

### 每場 JSON schema

```
{
  "line": { "away": {name, inn:[逐局], R, H, E}, "home": {...} },
  "fs":   [ {t:"1"客/"2"主, ord:棒次, acnt, name, no, ds:守位代碼, phr:"代打"/"代跑"/"", ev:進場事件} ],
  "bat":  { "<acnt>": {AB, H, RBI, R, HR, BB, SO} },
  "pit":  { "away":[{no,name,IP,H,ER,SO,NP,res}], "home":[...] },
  "info": {field, audience, dur:"HHMMSS", weather, win, lose, save, mvp, ump:{main,b1,b2,b3}}
}
```

## 打線重建演算法（前端）

與官網 box 頁 JS 相同邏輯：

1. `fs` 依 `t`（隊）分組，再依 `acnt` 分組（同一球員多列＝守位/代打歷程）
2. 每位球員的守位字串：依 `ev` 排序後串接
   - `phr=代打` → `(PH)`；`phr=代跑` → `(PR)`
   - 否則守位代碼經對照表轉英文縮寫；首列且 `ev='0000000000'`（先發）不加括號，其餘加括號（換人後守位）
3. 依 `(棒次, 是否先發)` 排序：同棒次先發在上、替補縮排在下

守位代碼對照：`0`=DH `1`=P `2`=C `3`=1B `4`=2B `5`=3B `6`=SS `7`=LF `8`=CF `9`=RF `10`=PH `11`=PR

## 抓取端

[scripts/update-scores.ps1](../scripts/update-scores.ps1)：`Get-GameLive`（單次 getlive）+ `Build-Box`（機械式抽取，中文僅透傳、重建邏輯留給前端）。`-BoxLimit N` 可限制單次抓幾場（測試/限流）。

## 設計 mockup

[design/box-view-mockup.html](../design/box-view-mockup.html)（game 165 真實資料）。
