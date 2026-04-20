# update-scores.ps1 - daily CPBL score fetcher, pure PowerShell (no bash/node deps)
# Called by update-scores.bat via Task Scheduler. See docs/scoreupdate.md plan D.

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$CpblBase = 'https://www.cpbl.com.tw'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'

function Write-Step($msg) { Write-Host "[step] $msg" }

Write-Step "Fetching CPBL schedule page for token..."
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$pageRes = Invoke-WebRequest `
    -Uri "$CpblBase/schedule" `
    -UserAgent $UA `
    -WebSession $session `
    -UseBasicParsing

$html = $pageRes.Content
$tokenMatches = [regex]::Matches($html, "RequestVerificationToken:\s*'([^']+)'")
if ($tokenMatches.Count -eq 0) {
    throw "Cannot find RequestVerificationToken in /schedule page (len=$($html.Length))"
}
$token = $tokenMatches[$tokenMatches.Count - 1].Groups[1].Value
Write-Step "Token acquired."

Write-Step "Fetching game data from API..."
$apiRes = Invoke-WebRequest `
    -Uri "$CpblBase/schedule/getgamedatas" `
    -Method Post `
    -UserAgent $UA `
    -WebSession $session `
    -Headers @{
        'RequestVerificationToken' = $token
        'X-Requested-With'         = 'XMLHttpRequest'
    } `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body 'CalendarDate=2026%2F06%2F01&GameSno=01&KindCode=A&Location=' `
    -UseBasicParsing

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
