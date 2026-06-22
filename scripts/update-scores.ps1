# update-scores.ps1 - daily CPBL score fetcher, pure PowerShell (no bash/node deps)
# Called by update-scores.bat via Task Scheduler. See docs/scoreupdate.md plan D.

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$CpblBase = 'https://www.cpbl.com.tw'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'

function Write-Step($msg) { Write-Host "[step] $msg" }

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

function Get-Briefing($session, $year, $sno) {
    $snoPadded = Pad3 $sno
    $boxUrl = "$CpblBase/box?year=$year&kindCode=A&gameSno=$snoPadded"
    try {
        $page = Invoke-WebRequest -Uri $boxUrl -UserAgent $UA -WebSession $session -UseBasicParsing
    } catch {
        return $null
    }
    $m = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
    if (-not $m.Success) { return $null }
    $tok = $m.Groups[1].Value
    $body = "__RequestVerificationToken=$([uri]::EscapeDataString($tok))&GameSno=$snoPadded&KindCode=A&Year=$year&PrevOrNext=&PresentStatus="
    try {
        $res = Invoke-WebRequest -Uri "$CpblBase/box/getlive" `
            -Method Post -UserAgent $UA -WebSession $session `
            -Headers @{ 'X-Requested-With' = 'XMLHttpRequest'; 'Referer' = $boxUrl } `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body $body -UseBasicParsing
    } catch {
        return $null
    }
    $json = $res.Content | ConvertFrom-Json
    if (-not $json.Success -or -not $json.CurtGameDetailJson) { return $null }
    $detail = $json.CurtGameDetailJson | ConvertFrom-Json
    return $detail.Briefing
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

# ── Briefings: fetch for finished games, cache in data/briefings.json ──
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

$boxSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$newCount = 0
foreach ($g in $games) {
    if ([string]$g.GameResult -ne '0') { continue }
    $sno = Pad3 $g.GameSno
    if ($briefings.Contains($sno) -and $briefings[$sno]) { continue }
    $brief = Get-Briefing $boxSession $g.Year $g.GameSno
    if ($brief) {
        $briefings[$sno] = [string]$brief
        $newCount++
        Write-Step "  + briefing $sno ($($g.GameDate.Substring(0,10)))"
    }
}
Write-Step "Fetched $newCount new briefings (total $($briefings.Count))."

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
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
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
