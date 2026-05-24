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

3. Deploy:

```bash
npm run deploy
```

4. Later, when real providers are enabled, add secrets:

```bash
wrangler secret put GEMINI_API_KEY
wrangler secret put QWEN_API_KEY
```

Current build uses mock responses only. Do not add provider API keys to source files.
