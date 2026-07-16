# fetch-news.ps1 - collect CPBL-related headlines from publisher RSS feeds and
# write data/news.json. COPYRIGHT-SAFE AGGREGATOR: stores ONLY headline title,
# source name, original article URL and publish time. Never stores article body
# or images. Each item links back to the original publisher. See docs/news.md.
#
# Saved as UTF-8 WITH BOM so PowerShell 5.1 reads the Chinese keyword regex
# correctly regardless of the system ANSI codepage.

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'

function Write-Step($msg) { Write-Host "[news] $msg" }

# Publisher-provided RSS feeds. A publisher offering RSS is inviting readers/
# aggregators to consume it; showing only "headline + link back to source" is the
# intended use. (Google News RSS is deliberately NOT used -- its own terms restrict
# it to personal, non-commercial feed-reader use. See docs/news.md.)
$Feeds = @(
    @{ name = '自由時報'; url = 'https://news.ltn.com.tw/rss/sports.xml' }
)

# A headline is kept only when it clearly concerns CPBL. Full team names are
# unambiguous; bare short names (統一/富邦/樂天) are avoided because they collide
# with other orgs and other-sport teams (e.g. 富邦勇士 is basketball).
$CpblRegex = '中職|中華職棒|職棒|中信兄弟|樂天桃猿|富邦悍將|統一7|統一獅|味全龍|台鋼雄鷹'

$KeepDays = 45     # drop items older than this
$MaxItems = 100    # hard cap on stored items

function Wait-Network {
    param([string]$HostName = 'news.ltn.com.tw', [int]$Port = 443, [int]$MaxTries = 8, [int]$DelaySec = 15)
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

function Parse-PubDate([string]$s) {
    # RSS pubDate is RFC-822, e.g. "Tue, 14 Jul 2026 17:22:51 +0800".
    # DateTimeOffset.Parse (InvariantCulture) handles the numeric offset fine.
    try {
        $dto = [System.DateTimeOffset]::Parse($s.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
        return $dto.ToString("yyyy-MM-ddTHH:mm:sszzz")
    } catch {
        return $null
    }
}

Wait-Network

# ---- Load existing archive so headlines accumulate over time ----
$newsPath = Join-Path $RepoRoot 'data/news.json'
$byUrl = [ordered]@{}
if (Test-Path $newsPath) {
    try {
        $prev = (Get-Content -Path $newsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        foreach ($it in $prev.items) {
            if ($it.url) { $byUrl[$it.url] = $it }
        }
        Write-Step "Loaded $($byUrl.Count) archived items."
    } catch {
        Write-Step "Existing news.json unreadable, starting fresh."
    }
}

# ---- Fetch each feed ----
$fetched = 0
foreach ($feed in $Feeds) {
    Write-Step "Fetching $($feed.name) ..."
    try {
        $res = Invoke-WebRequest -Uri $feed.url -UserAgent $UA -UseBasicParsing -TimeoutSec 25
    } catch {
        Write-Step "  FAILED $($feed.name): $($_.Exception.Message)"
        continue
    }
    # Strip any leading BOM / whitespace before the XML prolog, otherwise the
    # [xml] cast throws "node is the wrong type" on the BOM character.
    $content = [string]$res.Content
    $lt = $content.IndexOf('<')
    if ($lt -gt 0) { $content = $content.Substring($lt) }
    [xml]$doc = $content
    foreach ($item in $doc.rss.channel.item) {
        # Use InnerText: CDATA-wrapped fields (title/description in LTN's feed)
        # return an XmlElement via dotted access, not the string.
        $tNode = $item.SelectSingleNode('title')
        $lNode = $item.SelectSingleNode('link')
        $dNode = $item.SelectSingleNode('description')
        $pNode = $item.SelectSingleNode('pubDate')
        $title = if ($tNode) { $tNode.InnerText } else { '' }
        $link  = if ($lNode) { $lNode.InnerText } else { '' }
        $desc  = if ($dNode) { $dNode.InnerText } else { '' }
        if (-not $title -or -not $link) { continue }
        if (-not (($title + ' ' + $desc) -match $CpblRegex)) { continue }
        $iso = Parse-PubDate ($(if ($pNode) { $pNode.InnerText } else { '' }))
        if (-not $iso) { continue }
        # Newest wins on duplicate URL (title/time may get corrected upstream).
        $byUrl[$link] = [pscustomobject]@{
            title   = $title.Trim()
            url     = $link.Trim()
            source  = $feed.name
            pubDate = $iso
        }
        $fetched++
    }
}
Write-Step "Matched $fetched CPBL headlines this run."

# ---- Prune old + cap, sort newest first ----
$cutoff = (Get-Date).AddDays(-$KeepDays)
$items = @($byUrl.Values |
    Where-Object { [System.DateTimeOffset]::Parse($_.pubDate).LocalDateTime -ge $cutoff } |
    Sort-Object { [System.DateTimeOffset]::Parse($_.pubDate) } -Descending |
    Select-Object -First $MaxItems)

$out = [pscustomobject]@{
    updated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    count   = $items.Count
    items   = $items
}

# ConvertTo-Json escapes non-ASCII to \uXXXX, so news.json stays ASCII-clean.
$json = $out | ConvertTo-Json -Depth 5
$dataDir = Split-Path $newsPath
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($newsPath, $json, $utf8NoBom)
Write-Step "Wrote $($items.Count) items to data/news.json."
