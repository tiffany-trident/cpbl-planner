# cpbl-planner-api

CPBL Planner Phase 4 跨裝置同步後端 — Cloudflare Worker + KV + Google OAuth。

設計與切片計畫見 [`docs/phase4-sync-plan.md`](../../docs/phase4-sync-plan.md)。

## 第一次部署

```bash
cd cloudflare-worker/sync-api
npm install
npx wrangler login              # 瀏覽器授權 Cloudflare 帳號
npx wrangler deploy             # 部署到 cpbl-planner-api.tiffany-434.workers.dev
curl https://cpbl-planner-api.tiffany-434.workers.dev/healthz
# 期待：{"ok":true,"service":"cpbl-planner-api","ts":...}
```

## Secret 設定（切片 #3 OAuth callback 開做時再設）

```bash
npx wrangler secret put GOOGLE_CLIENT_SECRET    # 從 GCP console 複製
npx wrangler secret put SESSION_SIGNING_KEY     # 用 openssl rand -hex 32 產生
```

## 本機開發

```bash
npm run dev        # wrangler dev → http://localhost:8787
```

## 切片進度

見 [`docs/phase4-sync-plan.md` 「4-B 實作切片」](../../docs/phase4-sync-plan.md#4-b-實作切片incremental)。
