export interface Env {
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  SESSION_SIGNING_KEY: string;
  APP_ORIGIN: string;
  CPBL_USER_STORE: KVNamespace;
}

const SESSION_TTL_SECONDS = 30 * 24 * 3600;   // 30 天
const OAUTH_STATE_TTL_SECONDS = 600;          // 10 分鐘
const APP_REDIRECT_PATH = '/cpbl-planner/';   // GitHub Pages 子目錄

// ── helpers ──

function workerOrigin(req: Request): string {
  return new URL(req.url).origin;
}

function base64UrlEncode(input: ArrayBuffer | Uint8Array): string {
  const arr = input instanceof Uint8Array ? input : new Uint8Array(input);
  let s = '';
  for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function base64UrlEncodeJson(obj: unknown): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(obj)));
}

function base64UrlDecodeToString(b64url: string): string {
  let b64 = b64url.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) b64 += '=';
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function randomToken(byteLen = 32): string {
  const bytes = new Uint8Array(byteLen);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

async function signJWT(payload: Record<string, unknown>, secret: string): Promise<string> {
  const header = { alg: 'HS256', typ: 'JWT' };
  const data = `${base64UrlEncodeJson(header)}.${base64UrlEncodeJson(payload)}`;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));
  return `${data}.${base64UrlEncode(sig)}`;
}

// id_token 來自 Google over HTTPS，POC 不額外驗簽，正式版可加 JWKS 驗證
function decodeJwtPayloadUnverified(jwt: string): Record<string, unknown> {
  const parts = jwt.split('.');
  if (parts.length !== 3) throw new Error('JWT 結構不對');
  return JSON.parse(base64UrlDecodeToString(parts[1]));
}

function jsonError(status: number, message: string): Response {
  return Response.json({ ok: false, error: message }, { status });
}

// ── handlers ──

async function handleAuthLogin(req: Request, env: Env): Promise<Response> {
  const state = randomToken(24);
  await env.CPBL_USER_STORE.put(`oauth_state:${state}`, '1', {
    expirationTtl: OAUTH_STATE_TTL_SECONDS,
  });
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: `${workerOrigin(req)}/auth/callback`,
    scope: 'openid email profile',
    state,
    access_type: 'online',
  });
  return Response.redirect(
    `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
    302,
  );
}

async function handleAuthCallback(req: Request, env: Env): Promise<Response> {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const oauthError = url.searchParams.get('error');
  if (oauthError) return jsonError(400, `Google OAuth error: ${oauthError}`);
  if (!code || !state) return jsonError(400, 'Missing code or state in callback');

  // CSRF：驗 state 是不是我們發出去的
  const stateOk = await env.CPBL_USER_STORE.get(`oauth_state:${state}`);
  if (!stateOk) return jsonError(400, 'Invalid or expired oauth state');
  await env.CPBL_USER_STORE.delete(`oauth_state:${state}`);

  // code → tokens
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: `${workerOrigin(req)}/auth/callback`,
    }),
  });
  if (!tokenRes.ok) {
    return jsonError(500, `Token exchange failed: ${tokenRes.status} ${await tokenRes.text()}`);
  }
  const tokens = (await tokenRes.json()) as { id_token?: string };
  if (!tokens.id_token) return jsonError(500, 'Google response missing id_token');

  let info: { sub?: string; email?: string };
  try {
    info = decodeJwtPayloadUnverified(tokens.id_token) as { sub?: string; email?: string };
  } catch (e) {
    return jsonError(500, `Failed to decode id_token: ${(e as Error).message}`);
  }
  if (!info.sub || !info.email) return jsonError(500, 'id_token missing sub or email');

  // 簽自家 session JWT
  const now = Math.floor(Date.now() / 1000);
  const session = await signJWT(
    { sub: info.sub, email: info.email, iat: now, exp: now + SESSION_TTL_SECONDS },
    env.SESSION_SIGNING_KEY,
  );

  // cross-domain cookie 行不通 → session 走 URL fragment 帶回前端
  const target = `${env.APP_ORIGIN}${APP_REDIRECT_PATH}#session=${encodeURIComponent(session)}`;
  return Response.redirect(target, 302);
}

// ── main ──

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    if (req.method === 'GET' && url.pathname === '/healthz') {
      return Response.json({ ok: true, service: 'cpbl-planner-api', ts: Date.now() });
    }

    if (req.method === 'GET' && url.pathname === '/auth/login') {
      return handleAuthLogin(req, env);
    }

    if (req.method === 'GET' && url.pathname === '/auth/callback') {
      return handleAuthCallback(req, env);
    }

    return new Response('Not Found', { status: 404 });
  },
};
