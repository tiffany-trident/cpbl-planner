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
        $grStr
    )
    ConvertTo-Json -InputObject $row -Compress
}
$rawData = "const RAW_DATA = [`n" + ($lines -join ",`n") + "`n];"

Write-Step "Updating index.html..."
$indexPath = Join-Path $RepoRoot 'index.html'
$plannerPath = Join-Path $RepoRoot 'cpbl-planner.html'

$htmlFile = Get-Content -Path $indexPath -Raw -Encoding UTF8
$startIdx = $htmlFile.IndexOf('const RAW_DATA = [')
if ($startIdx -lt 0) { throw "Cannot find RAW_DATA in index.html" }
$endIdx = $htmlFile.IndexOf('];', $startIdx)
if ($endIdx -lt 0) { throw "Cannot find end of RAW_DATA in index.html" }
$endIdx += 2

$newHtml = $htmlFile.Substring(0, $startIdx) + $rawData + $htmlFile.Substring($endIdx)

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($indexPath, $newHtml, $utf8NoBom)
Copy-Item -Path $indexPath -Destination $plannerPath -Force
Write-Step "index.html + cpbl-planner.html updated."
