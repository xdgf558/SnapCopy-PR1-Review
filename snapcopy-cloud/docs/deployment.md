# Deployment

1. Install dependencies:

```bash
cd snapcopy-cloud
npm install
```

2. Run locally:

```bash
npm run dev
```

3. Apply D1 migrations:

```bash
npm run d1:migrate:local
npm run d1:migrate:remote
```

4. Deploy:

```bash
npm run deploy
```

5. Later, when real providers are enabled, add secrets:

```bash
wrangler secret put GEMINI_API_KEY
wrangler secret put DEEPSEEK_API_KEY
wrangler secret put QWEN_API_KEY
```

Use `DEFAULT_PROVIDER` to switch the active caption provider:

- `mock`
- `gemini`
- `deepseek`
- `qwen`

Current default is `mock`. Do not add provider API keys to source files.

Current build uses Cloudflare D1 for metadata-only quota and contribution records. Original photos are not uploaded.
