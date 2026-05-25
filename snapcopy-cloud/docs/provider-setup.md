# Caption Provider Setup

SnapCopy Cloud can route caption enhancement to mock or real text providers.

## Current Privacy Boundary

The caption endpoint does not upload original photos.

Real providers receive:

- `sceneJson`
- `userPreferenceJson`
- `targetPlatform`
- `locale`

## Providers

### Mock

```toml
DEFAULT_PROVIDER = "mock"
```

No secret is required.

### DeepSeek

```toml
DEFAULT_PROVIDER = "deepseek"
DEEPSEEK_MODEL = "deepseek-v4-flash"
DEEPSEEK_BASE_URL = "https://api.deepseek.com"
```

Set the secret:

```bash
wrangler secret put DEEPSEEK_API_KEY
```

Use `deepseek-v4-flash` first for cost control. Switch to `deepseek-v4-pro` if caption quality is not enough.

### Gemini

```toml
DEFAULT_PROVIDER = "gemini"
GEMINI_MODEL = "gemini-2.5-flash"
```

Set the secret:

```bash
wrangler secret put GEMINI_API_KEY
```

### Qwen / DashScope

```toml
DEFAULT_PROVIDER = "qwen"
QWEN_MODEL = "qwen-plus"
QWEN_BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
```

Set one of these secrets:

```bash
wrangler secret put DASHSCOPE_API_KEY
wrangler secret put QWEN_API_KEY
```

## Deploy

After changing provider settings:

```bash
npm run check
npm run deploy
```
