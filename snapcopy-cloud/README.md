# SnapCopy Cloud API

Cloudflare Worker for SnapCopy cloud enhancement.

Current scope:

- `POST /api/cloud-enhance/caption` returns cloud enhanced captions through the configured provider.
- `POST /api/cloud-enhance/vision` returns disabled.
- `GET /api/usage/status` returns backend quota from D1 when available.
- `POST /api/contributions/consent` records anonymous contribution consent.
- `POST /api/contributions/sample` records metadata-only contribution samples.
- A daily cron job creates pending caption strategy candidates after enough contributed samples accumulate.
- No photo upload is accepted by the caption endpoint.

## Local Development

```bash
cd snapcopy-cloud
npm install
npm run dev
```

Then test:

```bash
curl http://127.0.0.1:8787/api/usage/status?appUserId=00000000-0000-4000-8000-000000000000
```

## Deploy

```bash
cd snapcopy-cloud
npm run deploy
```

Future provider keys must be stored with Cloudflare secrets, never in iOS or Git:

```bash
wrangler secret put GEMINI_API_KEY
wrangler secret put DEEPSEEK_API_KEY
wrangler secret put QWEN_API_KEY
```

Set `DEFAULT_PROVIDER` in `wrangler.toml` to `gemini`, `deepseek`, or `qwen` to use a real text provider. Caption enhancement still sends only scene JSON, user preference JSON, locale, and target platform. Original photos are not uploaded.

## Contribution Optimization

Contribution data does not automatically train a model. The Worker aggregates anonymous caption samples into reviewable strategy candidates once a bucket reaches the configured threshold:

```toml
OPTIMIZATION_MIN_CAPTION_SAMPLES = "200"
OPTIMIZATION_COOLDOWN_HOURS = "72"
```

See `docs/contribution-optimization.md` for the review flow and manual trigger endpoint.
