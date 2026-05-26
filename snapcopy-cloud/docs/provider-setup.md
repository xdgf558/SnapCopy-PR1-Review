# Provider Setup

SnapCopy Cloud can route caption enhancement and image understanding to replaceable providers.

## Current Privacy Boundary

The caption endpoint does not upload original photos.

Real providers receive:

- `sceneJson`
- `userPreferenceJson`
- `targetPlatform`
- `locale`

The cloud image-understanding endpoint receives:

- A compressed image payload
- The existing local `sceneJson`
- `targetPlatform`
- `locale`

The Worker does not store the original uploaded image. If training samples are contributed, the current storage mode remains metadata-only unless a later version explicitly enables image storage with user consent.

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

## Image Understanding Providers

### Mock Vision

```toml
VISION_PROVIDER = "mock"
```

No secret is required. This is useful when testing quota, request flow, and client UI without image-model cost.

### GLM-4.6V

```toml
VISION_PROVIDER = "glm"
GLM_MODEL = "glm-4.6v"
GLM_BASE_URL = "https://open.bigmodel.cn/api/paas/v4"
```

Set the secret:

```bash
npx wrangler secret put GLM_API_KEY
```

The implementation uses an OpenAI-compatible chat-completions shape with an `image_url` data URL. If the provider changes the exact endpoint or message shape, only `src/providers/visionProviders.ts` should need adjustment.

Image understanding is an optional pre-step. If its provider fails, times out, or returns quota errors, the iOS app keeps the local scene JSON and continues with text enhancement.

## Deploy

After changing provider settings:

```bash
npm run check
npm run deploy
```
