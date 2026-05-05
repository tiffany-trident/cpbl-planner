export interface Env {
  GOOGLE_CLIENT_ID: string;
  APP_ORIGIN: string;
  // GOOGLE_CLIENT_SECRET: string;   // wrangler secret put
  // SESSION_SIGNING_KEY: string;    // wrangler secret put
  // CPBL_USER_STORE: KVNamespace;   // 切片 #2 綁定
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    if (req.method === 'GET' && url.pathname === '/healthz') {
      return Response.json({
        ok: true,
        service: 'cpbl-planner-api',
        ts: Date.now(),
      });
    }

    return new Response('Not Found', { status: 404 });
  },
};
