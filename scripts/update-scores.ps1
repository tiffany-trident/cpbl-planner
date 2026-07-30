# update-scores.ps1 - daily CPBL score fetcher, pure PowerShell (no bash/node deps)
# Called by update-scores.bat via Task Scheduler. See docs/scoreupdate.md plan D.

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    # Cap how many *new* box scores to fetch this run (0 = no cap). Handy for a
    # quick verification run so we don't pull ~180 games at once.
    [int]$BoxLimit = 0
)

$ErrorActionPreference = 'Stop'

$CpblBase = 'https://www.cpbl.com.tw'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'

function Write-Step($msg) { Write-Host "[step] $msg" }

# When this task is triggered by logon / session-unlock right after the laptop
# wakes from sleep, Wi-Fi is often still reconnecting and the very first request
# would throw under $ErrorActionPreference='Stop', failing the whole run. Wait for
# a TCP route to CPBL before fetching. See docs/scoreupdate.md 2026-06-29.
function Wait-Network {
    param([string]$HostName = 'www.cpbl.com.tw', [int]$Port = 443, [int]$MaxTries = 10, [int]$DelaySec = 15)
    for ($i = 1; $i -le $MaxTries; $i++) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $iar = $client.BeginConnect($HostName, $Port, $null, $null)
            $ok = $iar.AsyncWaitHandle.WaitOne(5000, $false)
            if ($ok -and $client.Connected) {
                $client.EndConnect($iar); $client.Close()
                Write-Step "Network ready (${HostName}:${Port}) after $i check(s)."
                return
            }
            $client.Close()
        } catch { }
        Write-Step "Network not ready (try $i/$MaxTries), waiting ${DelaySec}s..."
        Start-Sleep -Seconds $DelaySec
    }
    throw "Network to ${HostName}:${Port} not ready after $MaxTries tries"
}

# CPBL sits behind HiNet CDN, which answers a "cold" request (any method, no __chtcdn cookie yet)
# with a 308 Permanent Redirect to the SAME url plus Set-Cookie: __chtcdn=... -- a cookie challenge.
# PS 5.1 Invoke-WebRequest will not auto-follow a 308 (it throws on POST), so this wrapper catches
# the 308, copies __chtcdn into the session, and retries. Used for BOTH the schedule GET and the
# data POST because either can be the first (challenged) request. See docs/scoreupdate.md 2026-06-22.
function Invoke-CpblWeb {
    param(
        [string]$Uri,
        [string]$Method = 'Get',
        [hashtable]$Headers,
        [string]$ContentType,
        [string]$Body,
        $Session
    )
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $resp308 = $null
        try {
            $params = @{
                Uri                = $Uri
                Method             = $Method
                UserAgent          = $UA
                WebSession         = $Session
                MaximumRedirection = 0
                UseBasicParsing    = $true
            }
            if ($Headers)     { $params['Headers']     = $Headers }
            if ($ContentType) { $params['ContentType'] = $ContentType }
            if ($PSBoundParameters.ContainsKey('Body')) { $params['Body'] = $Body }
            $r = Invoke-WebRequest @params
            if ([int]$r.StatusCode -eq 308) { $resp308 = $r } else { return $r }
        } catch [System.Net.WebException] {
            $er = $_.Exception.Response
            if ($er -and [int]$er.StatusCode -eq 308) { $resp308 = $er } else { throw }
        }
        if ($resp308) {
            $setCookie = [string]$resp308.Headers['Set-Cookie']
            if ($setCookie -match '__chtcdn=([^;]+)') {
                $Session.Cookies.Add((New-Object System.Net.Cookie('__chtcdn', $matches[1], '/', 'www.cpbl.com.tw')))
                Write-Step "CDN 308 challenge on $Method $Uri -> stored __chtcdn, retry $attempt..."
                continue
            }
            throw "CPBL 308 on $Uri but no __chtcdn cookie in response"
        }
    }
    throw "CPBL request to $Uri failed after 3 attempts (CDN challenge unresolved)"
}

Wait-Network
Write-Step "Fetching CPBL schedule page for token..."
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$pageRes = Invoke-CpblWeb -Uri "$CpblBase/schedule" -Session $session

$html = $pageRes.Content
$tokenMatches = [regex]::Matches($html, "RequestVerificationToken:\s*'([^']+)'")
if ($tokenMatches.Count -eq 0) {
    throw "Cannot find RequestVerificationToken in /schedule page (len=$($html.Length))"
}
$token = $tokenMatches[$tokenMatches.Count - 1].Groups[1].Value
Write-Step "Token acquired."

Write-Step "Fetching game data from API..."
$apiRes = Invoke-CpblWeb `
    -Uri "$CpblBase/schedule/getgamedatas" `
    -Method Post `
    -Headers @{
        'RequestVerificationToken' = $token
        'X-Requested-With'         = 'XMLHttpRequest'
    } `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body 'CalendarDate=2026%2F06%2F01&GameSno=01&KindCode=A&Location=' `
    -Session $session

$data = $apiRes.Content | ConvertFrom-Json
if (-not $data.Success) {
    throw "CPBL API returned Success=false"
}
$games = $data.GameDatas | ConvertFrom-Json
if (-not $games -or $games.Count -eq 0) {
    throw "Game list is empty"
}
Write-Step "API response OK ($($games.Count) games)."

Write-Step "Building RAW_DATA..."
function Default([object]$val, [object]$fallback) {
    if ($null -eq $val) { return $fallback }
    return $val
}
function Pad3([object]$sno) {
    return ([int]$sno).ToString().PadLeft(3, '0')
}

# One getlive fetch per game; returns the parsed response (all sub-JSONs) or $null.
# Both the briefing and the box score are derived from this single response.
# Must go through Invoke-CpblWeb (not plain Invoke-WebRequest): on a fresh session
# the very FIRST box request hits HiNet's 308 __chtcdn cookie challenge, and plain
# Invoke-WebRequest silently drops it -- that dropped the first game (sno 001) on
# every cold run. The wrapper resolves the challenge and retries. See docs/scoreupdate.md.
function Get-GameLive($session, $year, $sno) {
    $snoPadded = Pad3 $sno
    $boxUrl = "$CpblBase/box?year=$year&kindCode=A&gameSno=$snoPadded"
    try {
        $page = Invoke-CpblWeb -Uri $boxUrl -Session $session
    } catch {
        return $null
    }
    $m = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
    if (-not $m.Success) { return $null }
    $tok = $m.Groups[1].Value
    $body = "__RequestVerificationToken=$([uri]::EscapeDataString($tok))&GameSno=$snoPadded&KindCode=A&Year=$year&PrevOrNext=&PresentStatus="
    try {
        $res = Invoke-CpblWeb -Uri "$CpblBase/box/getlive" `
            -Method Post -Session $session `
            -Headers @{ 'X-Requested-With' = 'XMLHttpRequest'; 'Referer' = $boxUrl } `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body $body
    } catch {
        return $null
    }
    $json = $res.Content | ConvertFrom-Json
    if (-not $json.Success -or -not $json.CurtGameDetailJson) { return $null }
    return $json
}

# Mechanical extraction only — sums for the line score, flat projections of the
# lineup / batting / pitching arrays. No Chinese string surgery (names & weather
# pass straight through as JSON values). The lineup棒次/代打 reconstruction and
# all display labels are done on the front end from these fields. See docs/box.md.
function Build-Box($json) {
    $box = [ordered]@{}
    $detail = $json.CurtGameDetailJson | ConvertFrom-Json

    # ── line score (per team, per inning, + R/H/E totals) ──
    $sb = $json.ScoreboardJson | ConvertFrom-Json
    $line = [ordered]@{}
    foreach ($t in @('1', '2')) {                       # 1 = 客隊(visiting), 2 = 主隊(home)
        $rows = @($sb | Where-Object { [string]$_.VisitingHomeType -eq $t } | Sort-Object InningSeq)
        if ($rows.Count -eq 0) { continue }
        $key = if ($t -eq '1') { 'away' } else { 'home' }
        $line[$key] = [ordered]@{
            name = [string]$rows[0].TeamAbbr
            inn  = @($rows | ForEach-Object { [int]$_.ScoreCnt })
            R    = ($rows | Measure-Object -Property ScoreCnt -Sum).Sum
            H    = ($rows | Measure-Object -Property HittingCnt -Sum).Sum
            E    = ($rows | Measure-Object -Property ErrorCnt -Sum).Sum
        }
    }
    $box.line = $line

    # ── first-sno rows (batting order + position code + 代打/代跑 marker) ──
    $fs = $json.FirstSnoJson | ConvertFrom-Json
    $box.fs = @($fs | Where-Object { [int]$_.Lineup -ne 0 } | ForEach-Object {
        [ordered]@{
            t    = [string]$_.VisitingHomeType
            ord  = [int]$_.Lineup
            acnt = [string]$_.Acnt
            name = [string]$_.CHName
            no   = [string]$_.UniformNo
            ds   = [string]$_.DefendStation      # numeric position code, mapped on front end
            phr  = [string]$_.PinchHitterRunner  # '代打' / '代跑' / ''
            ev   = [string]$_.MainEventNoS        # entry event; '0000000000' = starter
        }
    })

    # ── batting stats keyed by player account (front end joins to fs) ──
    $bat = $json.BattingJson | ConvertFrom-Json
    $batMap = [ordered]@{}
    foreach ($b in $bat) {
        $batMap[[string]$b.HitterAcnt] = [ordered]@{
            AB  = [int]$b.HitCnt
            H   = [int]$b.HittingCnt
            RBI = [int]$b.RunBattedINCnt
            R   = [int]$b.ScoreCnt
            HR  = [int]$b.HomeRunCnt
            BB  = ([int]$b.BasesONBallsCnt + [int]$b.HitBYPitchCnt)
            SO  = [int]$b.StrikeOutCnt
        }
    }
    $box.bat = $batMap

    # ── pitching (array order = appearance order) ──
    $pit = $json.PitchingJson | ConvertFrom-Json
    $pitOut = [ordered]@{}
    foreach ($t in @('1', '2')) {
        $rows = @($pit | Where-Object { [string]$_.VisitingHomeType -eq $t })
        $key = if ($t -eq '1') { 'away' } else { 'home' }
        $pitOut[$key] = @($rows | ForEach-Object {
            [ordered]@{
                no   = [string]$_.PitcherUniformNo
                name = [string]$_.PitcherName
                IP   = ("{0}.{1}" -f [int]$_.InningPitchedCnt, [int]$_.InningPitchedDiv3Cnt)
                H    = [int]$_.HittingCnt
                ER   = [int]$_.EarnedRunCnt
                SO   = [int]$_.StrikeOutCnt
                NP   = [int]$_.PitchCnt
                res  = [string]$_.GameResult   # '勝' / '敗' / ''
            }
        })
    }
    $box.pit = $pitOut

    # ── game info (durations/weather formatted on front end) ──
    $box.info = [ordered]@{
        field    = [string]$detail.FieldAbbe
        audience = [int]$detail.AudienceCnt
        dur      = [string]$detail.GameDuringTime   # 'HHMMSS', formatted on front end
        weather  = [string]$detail.WeatherDesc
        win      = [string]$detail.WinningPitcherName
        lose     = [string]$detail.LosePitcherName
        save     = [string]$detail.CloserPitcherName
        mvp      = [string]$detail.MvpName
        ump      = [ordered]@{
            main = [string]$detail.HeadUmpire
            b1   = [string]$detail.OneBaseReferee
            b2   = [string]$detail.TwoBaseReferee
            b3   = [string]$detail.TrheeBaseReferee
        }
    }

    return $box
}

$lines = foreach ($g in $games) {
    $gr = $g.GameResult
    if ($null -eq $gr) { $grStr = '' } else { $grStr = [string]$gr }
    $row = @(
        $g.GameDate.Substring(0, 10),
        $g.GameDateTimeS.Substring(11, 5),
        $g.VisitingTeamName,
        $g.HomeTeamName,
        $g.FieldAbbe,
        (Default $g.VisitingScore 0),
        (Default $g.HomeScore 0),
        (Default $g.WinningPitcherName ''),
        (Default $g.LoserPitcherName ''),
        (Default $g.CloserName ''),
        (Default $g.MvpName ''),
        $grStr,
        (Pad3 $g.GameSno)
    )
    ConvertTo-Json -InputObject $row -Compress
}
$rawData = "const RAW_DATA = [`n" + ($lines -join ",`n") + "`n];"

# ── Briefings + box scores: one getlive per finished game feeds both caches ──
Write-Step "Loading briefings cache..."
$briefingsPath = Join-Path $RepoRoot 'data/briefings.json'
$briefings = @{}
if (Test-Path $briefingsPath) {
    $cacheRaw = Get-Content -Path $briefingsPath -Raw -Encoding UTF8
    if ($cacheRaw.Trim()) {
        $parsed = $cacheRaw | ConvertFrom-Json
        foreach ($p in $parsed.PSObject.Properties) {
            $briefings[$p.Name] = [string]$p.Value
        }
    }
}
Write-Step "Cache has $($briefings.Count) briefings."

# Box scores are stored one JSON file per game under data/box/NNN.json, so the
# front end fetches only the game the user opened (~5 KB) instead of the whole
# season. "Cached" simply means the per-game file already exists.
$boxDir = Join-Path $RepoRoot 'data/box'
if (-not (Test-Path $boxDir)) { New-Item -ItemType Directory -Path $boxDir -Force | Out-Null }
$existingBox = @(Get-ChildItem -Path $boxDir -Filter '*.json' -ErrorAction SilentlyContinue).Count
Write-Step "Box cache has $existingBox game files."

$utf8NoBom = New-Object System.Text.UTF8Encoding $false   # used for per-game box files below and the caches later

$boxSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$newBrief = 0
$newBox = 0
foreach ($g in $games) {
    if ([string]$g.GameResult -ne '0') { continue }
    $sno = Pad3 $g.GameSno
    $boxPath = Join-Path $boxDir "$sno.json"
    $needBrief = -not ($briefings.Contains($sno) -and $briefings[$sno])
    $needBox = -not (Test-Path $boxPath)
    if (-not $needBrief -and -not $needBox) { continue }
    if ($needBox -and $BoxLimit -gt 0 -and $newBox -ge $BoxLimit) {
        if (-not $needBrief) { continue }   # box capped; still fill any missing briefing
        $needBox = $false
    }

    $live = Get-GameLive $boxSession $g.Year $g.GameSno
    if (-not $live) { continue }

    if ($needBrief) {
        $detail = $live.CurtGameDetailJson | ConvertFrom-Json
        if ($detail.Briefing) {
            $briefings[$sno] = [string]$detail.Briefing
            $newBrief++
            Write-Step "  + briefing $sno ($($g.GameDate.Substring(0,10)))"
        }
    }
    if ($needBox) {
        try {
            $box = Build-Box $live
            $boxJsonOne = ConvertTo-Json $box -Depth 12 -Compress
            [System.IO.File]::WriteAllText($boxPath, $boxJsonOne, $utf8NoBom)
            $newBox++
            Write-Step "  + box $sno ($($g.GameDate.Substring(0,10)))"
        } catch {
            Write-Step "  ! box $sno failed: $($_.Exception.Message)"
        }
    }
}
Write-Step "Fetched $newBrief new briefings (total $($briefings.Count)), $newBox new box scores (total $($existingBox + $newBox) game files)."

# 寫回快取（stable sort by sno，手動序列化避免 ConvertTo-Json 對 ordered dict 的古怪行為）
$sortedKeys = @($briefings.Keys | Sort-Object)
$jsonLines = foreach ($k in $sortedKeys) {
    $valJson = ConvertTo-Json $briefings[$k] -Depth 3 -Compress
    '  "' + $k + '": ' + $valJson
}
if ($jsonLines.Count -eq 0) {
    $briefJson = "{}"
} else {
    $briefJson = "{`n" + ($jsonLines -join ",`n") + "`n}"
}
$dataDir = Split-Path $briefingsPath
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
[System.IO.File]::WriteAllText($briefingsPath, $briefJson, $utf8NoBom)

# 組裝要注入 HTML 的 BRIEFINGS 區塊（以 marker 界定，方便反覆置換）
$briefingsBlock = "// BRIEFINGS-START`nconst BRIEFINGS = " + [string]$briefJson + ";`n// BRIEFINGS-END"

Write-Step "Updating index.html..."
$indexPath = Join-Path $RepoRoot 'index.html'
$plannerPath = Join-Path $RepoRoot 'cpbl-planner.html'

$htmlFile = Get-Content -Path $indexPath -Raw -Encoding UTF8

# 置換 RAW_DATA
$startIdx = $htmlFile.IndexOf('const RAW_DATA = [')
if ($startIdx -lt 0) { throw "Cannot find RAW_DATA in index.html" }
$endIdx = $htmlFile.IndexOf('];', $startIdx)
if ($endIdx -lt 0) { throw "Cannot find end of RAW_DATA in index.html" }
$endIdx += 2
$htmlFile = $htmlFile.Substring(0, $startIdx) + $rawData + $htmlFile.Substring($endIdx)

# Replace BRIEFINGS block using markers
$markBegin = '// BRIEFINGS-START'
$markClose = '// BRIEFINGS-END'
$bStart = $htmlFile.IndexOf($markBegin)
if ($bStart -lt 0) { throw "Cannot find marker in index.html" }
$bEndIdx = $htmlFile.IndexOf($markClose, $bStart)
if ($bEndIdx -lt 0) { throw "Cannot find end marker in index.html" }
$bEnd = $bEndIdx + $markClose.Length
$htmlFile = $htmlFile.Substring(0, $bStart) + $briefingsBlock + $htmlFile.Substring($bEnd)

[System.IO.File]::WriteAllText($indexPath, $htmlFile, $utf8NoBom)
Copy-Item -Path $indexPath -Destination $plannerPath -Force
Write-Step "index.html + cpbl-planner.html updated."
