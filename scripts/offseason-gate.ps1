# offseason-gate.ps1 - decide whether update-scores.bat should run this time.
# Called by update-scores.bat before anything touches git. Pure ASCII on purpose
# (Task Scheduler + PS 5.1, see docs/scoreupdate.md).
#
# In season (RAW_DATA has a game dated today or later): always run -> exit 0.
# Offseason (every game is in the past): run once per day -> exit 0 on the first
# trigger of the day, exit 3 (= skip) once logs/last-run-date.txt says today.
# The bat writes that stamp only after a successful push, so a failed run retries
# on the next trigger. The season resumes automatically as soon as RAW_DATA gets
# future games (e.g. the 2027 schedule is loaded).
#
# Any error -> exit 0 (run as before); the gate must never block a real update.
#
# Test: powershell -File scripts\offseason-gate.ps1 -Today 2026-11-09 -Verbose

param(
    [string]$Today = (Get-Date -Format 'yyyy-MM-dd')
)

try {
    $repo = Split-Path -Parent $PSScriptRoot
    $html = [IO.File]::ReadAllText((Join-Path $repo 'index.html'), [Text.Encoding]::UTF8)
    $start = $html.IndexOf('const RAW_DATA = [')
    if ($start -lt 0) { Write-Output '[gate] RAW_DATA not found -- run'; exit 0 }
    $end = $html.IndexOf('];', $start)
    $block = $html.Substring($start, $end - $start)

    # Each row starts with its date: ["2026-03-28","17:06",...
    $last = ''
    foreach ($m in [regex]::Matches($block, '\["(\d{4}-\d{2}-\d{2})"')) {
        $d = $m.Groups[1].Value
        if ($d -gt $last) { $last = $d }
    }
    if ($last -eq '' -or $last -ge $Today) {
        Write-Verbose "[gate] in season (last game $last) -- run"
        exit 0
    }

    $stamp = Join-Path $repo 'logs\last-run-date.txt'
    $ranOn = if (Test-Path $stamp) { (Get-Content $stamp -TotalCount 1).Trim() } else { '' }
    if ($ranOn -eq $Today) {
        Write-Output "[gate] offseason (last game $last), already ran $ranOn -- skip"
        exit 3
    }
    Write-Output "[gate] offseason (last game $last), first run of $Today -- run"
    exit 0
} catch {
    Write-Output "[gate] error: $($_.Exception.Message) -- run"
    exit 0
}
