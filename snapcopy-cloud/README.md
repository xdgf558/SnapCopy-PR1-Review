# SnapCopy Cloud API

Cloudflare Worker skeleton for SnapCopy cloud enhancement.

Current scope:

- `POST /api/cloud-enhance/caption` returns mock enhanced captions.
- `POST /api/cloud-enhance/vision` returns disabled.
- `GET /api/usage/status` returns mock daily quota.
- No Gemini/Qwen API key is used.
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
