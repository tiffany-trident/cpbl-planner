/**
 * CPBL Schedule Fetcher — Cloudflare Worker
 *
 * 代理 CPBL 官網兩步驟請求（維持 cookie + antiforgery token 配對），
 * 回傳精簡後的賽程陣列。前端（GitHub Pages）以單一 GET 呼叫即可取得最新比分。
 *
 * 部署步驟見 docs/scoreupdate.md。
 */

const CPBL_BASE = 'https://www.cpbl.com.tw';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

// 允許呼叫此 Worker 的來源。多個 origin 以逗號分隔。
// 設定為 '*' 可開放所有來源（不需要認證，純公開賽程資料可接受）。
const ALLOWED_ORIGIN = '*';

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Cache-Control': 'no-store',
  };
}

function jsonResponse(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...corsHeaders() },
  });
}

// 從 Set-Cookie header 收集 name=value 組合
function collectCookies(setCookieHeaders) {
  const jar = {};
  for (const line of setCookieHeaders) {
    const first = line.split(';')[0];
    const eq = first.indexOf('=');
    if (eq > 0) {
      jar[first.slice(0, eq).trim()] = first.slice(eq + 1).trim();
    }
  }
  return jar;
}

function cookieString(jar) {
  return Object.entries(jar).map(([k, v]) => `${k}=${v}`).join('; ');
}

// 解析 Set-Cookie（Cloudflare Workers 提供 getSetCookie()，但保險用手動拆）
function getSetCookies(headers) {
  if (typeof headers.getSetCookie === 'function') {
    return headers.getSetCookie();
  }
  const raw = headers.get('set-cookie');
  return raw ? [raw] : [];
}

async function tryGet(path) {
  return fetch(`${CPBL_BASE}${path}`, {
    headers: {
      'User-Agent': UA,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
      'sec-ch-ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
    },
    redirect: 'follow',
  });
}

async function fetchSchedule() {
  // CPBL 對 Worker IP 擋 /schedule，但首頁 / 會放行，先從首頁拿 token + cookie
  const pageRes = await tryGet('/');
  if (!pageRes.ok) {
    throw new Error(`GET / HTTP ${pageRes.status}`);
  }
  const jar = collectCookies(getSetCookies(pageRes.headers));
  const html = await pageRes.text();

  // 優先用 JS 字面值裡的 token（原本的格式），退而求其次用 hidden input
  let token = '';
  const jsMatches = [...html.matchAll(/RequestVerificationToken:\s*'([^']+)'/g)];
  if (jsMatches.length) {
    token = jsMatches[jsMatches.length - 1][1];
  } else {
    const inputMatch = html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/);
    if (inputMatch) token = inputMatch[1];
  }
  if (!token) {
    throw new Error(`找不到 token（首頁長度=${html.length}）`);
  }

  // Step 2: POST /schedule/getgamedatas 帶 cookie + token
  const apiRes = await fetch(`${CPBL_BASE}/schedule/getgamedatas`, {
    method: 'POST',
    headers: {
      'User-Agent': UA,
      'Content-Type': 'application/x-www-form-urlencoded',
      'RequestVerificationToken': token,
      'X-Requested-With': 'XMLHttpRequest',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language': 'zh-TW,zh;q=0.9',
      'Origin': CPBL_BASE,
      'Referer': `${CPBL_BASE}/schedule`,
      'Cookie': cookieString(jar),
    },
    body: 'CalendarDate=2026%2F06%2F01&GameSno=01&KindCode=A&Location=',
  });
  if (!apiRes.ok) {
    throw new Error(`POST /getgamedatas HTTP ${apiRes.status}`);
  }
  const data = await apiRes.json();
  if (!data.Success) {
    throw new Error('CPBL API 回傳 Success=false');
  }
  const games = JSON.parse(data.GameDatas);
  if (!Array.isArray(games) || !games.length) {
    throw new Error('賽程資料為空');
  }

  // 精簡為 [date, time, visitor, home, field, vScore, hScore, wp, lp, sv, mvp, gr]
  return games.map(g => [
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
  ]);
}

export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== 'GET') {
      return jsonResponse({ ok: false, error: 'Method Not Allowed' }, 405);
    }
    try {
      const rows = await fetchSchedule();
      return jsonResponse({ ok: true, count: rows.length, rows });
    } catch (e) {
      return jsonResponse({ ok: false, error: String(e && e.message || e) }, 502);
    }
  },
};
