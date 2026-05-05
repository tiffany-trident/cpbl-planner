export interface Env {
  GOOGLE_CLIENT_ID: string;
  APP_ORIGIN: string;
  CPBL_USER_STORE: KVNamespace;
  // GOOGLE_CLIENT_SECRET: string;   // wrangler secret put（切片 #3）
  // SESSION_SIGNING_KEY: string;    // wrangler secret put（切片 #3）
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    if (req.method === 'GET' && url.pathname === '/healthz') {
      // 試一次 KV write/read 確認 binding 通
      let kv: 'ok' | 'fail' = 'fail';
      try {
        const sentinel = `healthz:${Date.now()}`;
        await env.CPBL_USER_STORE.put('_healthz', sentinel, { expirationTtl: 60 });
        const got = await env.CPBL_USER_STORE.get('_healthz');
        kv = got === sentinel ? 'ok' : 'fail';
      } catch {
        kv = 'fail';
      }
      return Response.json({
        ok: true,
        service: 'cpbl-planner-api',
        ts: Date.now(),
        kv,
      });
    }

    return new Response('Not Found', { status: 404 });
  },
};
