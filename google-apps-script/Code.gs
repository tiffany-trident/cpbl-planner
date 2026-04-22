/**
 * CPBL Schedule Fetcher — Google Apps Script Web App
 *
 * 用途：代理 CPBL 官網兩步驟請求（首頁抓 token + cookie → POST /schedule/getgamedatas），
 * 回傳精簡後的賽程陣列。因 CPBL 封鎖 Cloudflare Workers IP，改走 Google 基礎設施。
 *
 * 部署步驟見 docs/scoreupdate.md 方案 A5。
 */

var CPBL_BASE = 'https://www.cpbl.com.tw';
var UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

function doGet(e) {
  try {
    // ?debug=probe → 對多個候選頁測 HTTP status + cookie 名稱 + 是否有 token
    if (e && e.parameter && e.parameter.debug === 'probe') {
      return jsonOut(probeCandidatePages());
    }
    // ?source=/path → 指定從哪個頁面拿 token（預設 /）
    var source = (e && e.parameter && e.parameter.source) || '/';
    var rows = fetchSchedule(source);
    return jsonOut({ ok: true, count: rows.length, source: source, rows: rows });
  } catch (err) {
    return jsonOut({ ok: false, error: String(err && err.message || err) });
  }
}

function probeCandidatePages() {
  var candidates = [
    '/', '/schedule', '/standings', '/team', '/box/index', '/stats/all/pitcher',
    '/member', '/member/login', '/ticket', '/live', '/live/index',
    '/news', '/news/index', '/about', '/elect', '/history',
    '/schedule/index', '/Schedule', '/home', '/home/index'
  ];
  var results = [];
  for (var i = 0; i < candidates.length; i++) {
    var path = candidates[i];
    try {
      var res = UrlFetchApp.fetch(CPBL_BASE + path, {
        method: 'get',
        headers: { 'User-Agent': UA, 'Accept': 'text/html,*/*' },
        followRedirects: true,
        muteHttpExceptions: true,
      });
      var code = res.getResponseCode();
      var html = code === 200 ? res.getContentText() : '';
      var jar = code === 200 ? collectCookies(res) : {};
      var tokenMatch = html.match(/RequestVerificationToken:\s*'([^']+)'/);
      var inputMatch = html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/);
      results.push({
        path: path,
        status: code,
        htmlLen: html.length,
        cookies: Object.keys(jar),
        hasJsToken: !!tokenMatch,
        hasInputToken: !!inputMatch,
        tokenPreview: (tokenMatch ? tokenMatch[1] : (inputMatch ? inputMatch[1] : '')).slice(0, 20),
      });
    } catch (err) {
      results.push({ path: path, error: String(err && err.message || err) });
    }
  }
  return { probe: results };
}

function jsonOut(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// 從回應 headers 擷取 Set-Cookie → {name: value}
function collectCookies(response) {
  var headers = response.getAllHeaders();
  var raw = headers['Set-Cookie'] || headers['set-cookie'] || [];
  var lines = Array.isArray(raw) ? raw : [raw];
  var jar = {};
  for (var i = 0; i < lines.length; i++) {
    var first = String(lines[i]).split(';')[0];
    var eq = first.indexOf('=');
    if (eq > 0) {
      jar[first.slice(0, eq).trim()] = first.slice(eq + 1).trim();
    }
  }
  return jar;
}

function cookieString(jar) {
  var parts = [];
  for (var k in jar) {
    if (Object.prototype.hasOwnProperty.call(jar, k)) {
      parts.push(k + '=' + jar[k]);
    }
  }
  return parts.join('; ');
}

function fetchSchedule(sourcePath) {
  // Step 1: GET <sourcePath> 拿 token + antiforgery cookie
  // 預設 '/'，CPBL 對 Google IP 擋 /schedule，但首頁/其他頁面放行
  var pageRes = UrlFetchApp.fetch(CPBL_BASE + sourcePath, {
    method: 'get',
    headers: {
      'User-Agent': UA,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
    },
    followRedirects: true,
    muteHttpExceptions: true,
  });
  if (pageRes.getResponseCode() !== 200) {
    throw new Error('GET ' + sourcePath + ' HTTP ' + pageRes.getResponseCode());
  }
  var jar = collectCookies(pageRes);
  var html = pageRes.getContentText();

  // 優先用 JS 字面值裡的 token；退而求其次用 hidden input
  var token = '';
  var jsRe = /RequestVerificationToken:\s*'([^']+)'/g;
  var m;
  var last = null;
  while ((m = jsRe.exec(html)) !== null) last = m;
  if (last) {
    token = last[1];
  } else {
    var inputMatch = html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/);
    if (inputMatch) token = inputMatch[1];
  }
  if (!token) {
    throw new Error('找不到 token（首頁長度=' + html.length + '）');
  }

  // Step 2: POST /schedule/getgamedatas（header 盡量精簡，對齊 fetch-scores.sh 的成功樣態）
  var apiRes = UrlFetchApp.fetch(CPBL_BASE + '/schedule/getgamedatas', {
    method: 'post',
    contentType: 'application/x-www-form-urlencoded',
    headers: {
      'User-Agent': UA,
      'RequestVerificationToken': token,
      'X-Requested-With': 'XMLHttpRequest',
      'Cookie': cookieString(jar),
    },
    payload: 'CalendarDate=2026%2F06%2F01&GameSno=01&KindCode=A&Location=',
    followRedirects: true,
    muteHttpExceptions: true,
  });
  if (apiRes.getResponseCode() !== 200) {
    throw new Error('POST /getgamedatas HTTP ' + apiRes.getResponseCode());
  }
  var data = JSON.parse(apiRes.getContentText());
  if (!data.Success) {
    throw new Error('CPBL API 回傳 Success=false');
  }
  var games = JSON.parse(data.GameDatas);
  if (!Array.isArray(games) || !games.length) {
    throw new Error('賽程資料為空');
  }

  // 精簡為 [date, time, visitor, home, field, vScore, hScore, wp, lp, sv, mvp, gr]
  return games.map(function (g) {
    return [
      g.GameDate.slice(0, 10),
      g.GameDateTimeS.slice(11, 16),
      g.VisitingTeamName,
      g.HomeTeamName,
      g.FieldAbbe,
      g.VisitingScore || 0,
      g.HomeScore || 0,
      g.WinningPitcherName || '',
      g.LoserPitcherName || '',
      g.CloserName || '',
      g.MvpName || '',
      g.GameResult == null ? '' : String(g.GameResult),
    ];
  });
}
