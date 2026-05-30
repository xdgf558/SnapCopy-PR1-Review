import type { ModelStrategy } from "../config/model-strategies";
import { parseCaptionsFromProviderText } from "../providers/captionParser";
import type { CloudEnhancementImagePayload } from "../types/api";

export type AiProviderEnv = {
  GLM_API_KEY?: string;
  GLM_BASE_URL?: string;
  DEEPSEEK_API_KEY?: string;
  DEEPSEEK_BASE_URL?: string;
};

export type EnhanceCaptionParams = {
  env: AiProviderEnv;
  imagePayload?: CloudEnhancementImagePayload | null;
  sceneJson?: string | null;
  userPreference?: Record<string, unknown> | string | null;
  targetPlatform?: string;
  locale?: string;
  strategy: ModelStrategy;
};

export type EnhanceResult = {
  captions: string[];
  provider: "mock" | "glm" | "deepseek";
  model: string;
  inputTokens: number;
  outputTokens: number;
  estimatedCostUsd: number | null;
  cloudUnitsUsed: number;
};

type OpenAICompatibleChatResponse = {
  choices?: Array<{
    message?: {
      content?: string;
    };
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
  };
  error?: {
    message?: string;
  };
};

type ChatMessage = {
  role: "system" | "user";
  content:
    | string
    | Array<
        | {
            type: "text";
            text: string;
          }
        | {
            type: "image_url";
            image_url: {
              url: string;
            };
          }
      >;
};

type ProviderConfig = {
  provider: "glm" | "deepseek";
  displayName: string;
  apiKey?: string;
  baseUrl: string;
  model: string;
};

const DEFAULT_AI_PROVIDER_TIMEOUT_MS = 30_000;

export class AiProviderError extends Error {
  constructor(
    message: string,
    readonly statusCode = 502
  ) {
    super(message);
    this.name = "AiProviderError";
  }
}

export async function enhanceCaption(params: EnhanceCaptionParams): Promise<EnhanceResult> {
  const modelName = params.strategy.modelName.trim();

  if (!modelName || modelName === "placeholder") {
    return makeMockEnhanceResult(params);
  }

  const provider = providerForModel(modelName);
  const config = providerConfigFor(provider, modelName, params.env);
  if (!config.apiKey) {
    throw new AiProviderError(`${config.displayName} API key is not configured.`, 500);
  }

  const prompt = boundPrompt(buildEnhancementPrompt(params), params.strategy.maxPromptTokens);
  const messages = buildMessages(params, config.provider, prompt);
  const { response, json } = await fetchOpenAICompatibleJson(
    chatCompletionsUrl(config),
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: config.model,
        messages,
        temperature: config.provider === "glm" ? 0.65 : 0.78,
        max_tokens: params.strategy.maxOutputTokens,
        response_format: {
          type: "json_object"
        }
      })
    },
    config.displayName,
    timeoutMsForStrategy(params.strategy)
  );

  if (!response.ok) {
    throw new AiProviderError(providerErrorMessage(config.displayName, response.status, json.error?.message), 502);
  }

  const text = json.choices?.[0]?.message?.content?.trim() ?? "";
  const captions = parseCaptionsFromProviderText(text).slice(0, params.strategy.captionCount);
  if (captions.length === 0) {
    throw new AiProviderError(`${config.displayName} returned no usable captions.`, 502);
  }

  const inputTokens = json.usage?.prompt_tokens ?? estimateTokens(prompt);
  const outputTokens = json.usage?.completion_tokens ?? estimateTokens(captions.join("\n"));

  return {
    captions,
    provider: config.provider,
    model: config.model,
    inputTokens,
    outputTokens,
    estimatedCostUsd: estimateCostUsd(config.provider, config.model, inputTokens, outputTokens),
    cloudUnitsUsed: 1
  };
}

function providerForModel(modelName: string): "glm" | "deepseek" {
  const normalized = modelName.toLowerCase();
  if (normalized.startsWith("glm") || normalized.includes("glm-")) {
    return "glm";
  }

  if (normalized.startsWith("deepseek") || normalized.includes("deepseek")) {
    return "deepseek";
  }

  throw new AiProviderError(`Unsupported strategy modelName: ${modelName}`, 500);
}

function providerConfigFor(provider: "glm" | "deepseek", model: string, env: AiProviderEnv): ProviderConfig {
  if (provider === "glm") {
    return {
      provider,
      displayName: "GLM",
      apiKey: env.GLM_API_KEY,
      baseUrl: env.GLM_BASE_URL ?? "https://open.bigmodel.cn/api/paas/v4",
      model
    };
  }

  return {
    provider,
    displayName: "DeepSeek",
    apiKey: env.DEEPSEEK_API_KEY,
    baseUrl: env.DEEPSEEK_BASE_URL ?? "https://api.deepseek.com",
    model
  };
}

function chatCompletionsUrl(config: ProviderConfig): string {
  const baseUrl = config.baseUrl.replace(/\/+$/, "");
  if (config.provider === "deepseek" && !baseUrl.endsWith("/v1")) {
    return `${baseUrl}/v1/chat/completions`;
  }

  return `${baseUrl}/chat/completions`;
}

function buildMessages(params: EnhanceCaptionParams, provider: "glm" | "deepseek", prompt: string): ChatMessage[] {
  const content = buildUserContent(params, provider, prompt);
  return [
    {
      role: "system",
      content:
        "You are SnapCopy's senior social caption writer. Return strict JSON only and never mention metadata, labels, JSON, AI, or model analysis."
    },
    {
      role: "user",
      content
    }
  ];
}

function buildUserContent(
  params: EnhanceCaptionParams,
  provider: "glm" | "deepseek",
  prompt: string
): ChatMessage["content"] {
  if (provider !== "glm" || !params.imagePayload) {
    return prompt;
  }

  const imageUrl = imageUrlFromPayload(params.imagePayload, params.strategy);
  if (!imageUrl) {
    return prompt;
  }

  return [
    {
      type: "text",
      text: prompt
    },
    {
      type: "image_url",
      image_url: {
        url: imageUrl
      }
    }
  ];
}

function imageUrlFromPayload(payload: CloudEnhancementImagePayload, strategy: ModelStrategy): string | null {
  if (payload.imageUrl?.trim()) {
    return payload.imageUrl.trim();
  }

  if (!payload.imageBase64?.trim()) {
    return null;
  }

  const imageBase64 = payload.imageBase64.replace(/^data:[^;]+;base64,/i, "").trim();
  const byteLength = approximateBase64ByteLength(imageBase64);
  if (byteLength > strategy.maxImageSizeBytes) {
    throw new AiProviderError(
      `Image payload exceeds ${strategy.name} strategy size limit (${strategy.maxImageSizeBytes} bytes).`,
      413
    );
  }

  return `data:${payload.imageMimeType ?? "image/jpeg"};base64,${imageBase64}`;
}

function buildEnhancementPrompt(params: EnhanceCaptionParams): string {
  const strategy = params.strategy;
  const targetPlatform = allowedOrFallback(params.targetPlatform, strategy.allowedPlatforms, "general");
  const locale = allowedLocaleOrFallback(params.locale, strategy.allowedLocales);
  const effectiveImageDimension = effectiveImageDimensionFor(strategy);
  const payload = {
    sceneJson: safeParseJson(params.sceneJson ?? "{}"),
    userPreference: safeParseUserPreference(params.userPreference),
    targetPlatform,
    locale,
    strategy: {
      name: strategy.name,
      modelName: strategy.modelName,
      captionCount: strategy.captionCount,
      maxImageDimension: effectiveImageDimension,
      maxPromptTokens: strategy.maxPromptTokens,
      maxOutputTokens: strategy.maxOutputTokens
    }
  };

  return [
    "Generate polished social captions for SnapCopy.",
    "Return only valid JSON. No Markdown. No explanation outside JSON.",
    `JSON shape: {"captions":["caption 1","caption 2","caption 3","caption 4","caption 5"]}.`,
    `Write exactly ${strategy.captionCount} captions.`,
    `Write in locale: ${locale}.`,
    `Target platform: ${targetPlatform}.`,
    `Image processing mode: ${strategy.name}; treat attached images as compressed to max ${effectiveImageDimension}px.`,
    "Use concrete scene details. Avoid generic filler. Do not invent unsupported details.",
    "Vary the captions: warm, concise, premium-polished, slightly playful, and grounded.",
    "Do not mention JSON, labels, OCR, confidence, provider, prompt, or model analysis in captions.",
    "",
    "Input payload:",
    JSON.stringify(payload, null, 2)
  ].join("\n");
}

function safeParseJson(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function safeParseUserPreference(value: Record<string, unknown> | string | null | undefined): unknown {
  if (typeof value === "string") {
    return safeParseJson(value);
  }

  return value ?? {};
}

function allowedOrFallback<T extends string>(value: string | undefined, allowedValues: readonly T[], fallback: T): T {
  const normalized = value?.trim().toLowerCase() as T | undefined;
  return normalized && allowedValues.includes(normalized) ? normalized : fallback;
}

function allowedLocaleOrFallback(value: string | undefined, allowedLocales: readonly string[]): string {
  const normalized = normalizeLocale(value);
  if (allowedLocales.includes(normalized)) {
    return normalized;
  }

  if (normalized.startsWith("zh") && allowedLocales.includes("zh-Hans")) {
    return "zh-Hans";
  }

  return allowedLocales[0] ?? "en";
}

function normalizeLocale(value: string | undefined): string {
  const normalized = value?.trim() ?? "";
  if (/^zh[-_]hant/i.test(normalized)) {
    return "zh-Hant";
  }

  if (/^zh[-_]hans/i.test(normalized) || /^zh/i.test(normalized)) {
    return "zh-Hans";
  }

  if (/^ja/i.test(normalized)) {
    return "ja";
  }

  if (/^en/i.test(normalized)) {
    return "en";
  }

  return normalized || "en";
}

function effectiveImageDimensionFor(strategy: ModelStrategy): number {
  return Math.min(strategy.maxImageDimension, strategy.name === "balanced" ? 512 : 1024);
}

function timeoutMsForStrategy(strategy: ModelStrategy): number {
  return strategy.name === "balanced" ? 15_000 : 30_000;
}

function boundPrompt(prompt: string, maxPromptTokens: number): string {
  const maxChars = Math.max(1000, maxPromptTokens * 4);
  if (prompt.length <= maxChars) {
    return prompt;
  }

  return `${prompt.slice(0, maxChars)}\n\n[Prompt truncated to strategy maxPromptTokens.]`;
}

async function fetchOpenAICompatibleJson(
  url: string,
  init: RequestInit,
  displayName: string,
  timeoutMs = DEFAULT_AI_PROVIDER_TIMEOUT_MS
): Promise<{ response: Response; json: OpenAICompatibleChatResponse }> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...init,
      signal: controller.signal
    });
    const json = (await response.json().catch(() => ({}))) as OpenAICompatibleChatResponse;
    return { response, json };
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") {
      throw new AiProviderError(`${displayName} enhancement timed out.`, 504);
    }

    const message = error instanceof Error ? error.message : "unknown network error";
    throw new AiProviderError(`${displayName} enhancement request failed: ${message}`, 502);
  } finally {
    clearTimeout(timeout);
  }
}

function makeMockEnhanceResult(params: EnhanceCaptionParams): EnhanceResult {
  const scene = extractScene(params.sceneJson);
  const platform = params.targetPlatform?.trim() || "general";
  const strategyName = params.strategy.name;
  return {
    captions: [
      `${scene} 的氛围已经准备好，后续会用 ${strategyName} 策略生成更贴合画面的文案。`,
      `这是一条适合 ${platform} 的统一增强 mock 文案。`,
      "真实模型接入后，这里会结合图片理解、用户偏好和平台风格生成。"
    ].slice(0, params.strategy.captionCount),
    provider: "mock",
    model: "placeholder",
    inputTokens: 0,
    outputTokens: 0,
    estimatedCostUsd: 0,
    cloudUnitsUsed: 0
  };
}

function extractScene(sceneJson: string | null | undefined): string {
  const parsed = typeof sceneJson === "string" ? safeParseJson(sceneJson) : undefined;
  if (!parsed || typeof parsed !== "object") {
    return "这张照片";
  }

  const objectValue = parsed as Record<string, unknown>;
  const resolvedScene = objectValue.resolvedScene;
  if (resolvedScene && typeof resolvedScene === "object") {
    const scene = (resolvedScene as Record<string, unknown>).scene;
    if (typeof scene === "string" && scene.trim()) {
      return scene;
    }
  }

  const scene = objectValue.primaryScene ?? objectValue.scene;
  return typeof scene === "string" && scene.trim() ? scene : "这张照片";
}

function estimateTokens(text: string): number {
  return Math.max(1, Math.ceil(text.length / 4));
}

function approximateBase64ByteLength(value: string): number {
  const padding = value.endsWith("==") ? 2 : value.endsWith("=") ? 1 : 0;
  return Math.max(0, Math.floor((value.length * 3) / 4) - padding);
}

function estimateCostUsd(provider: "glm" | "deepseek", model: string, inputTokens: number, outputTokens: number): number {
  const price = pricePer1kTokens(provider, model);
  const cost = (inputTokens / 1000) * price.input + (outputTokens / 1000) * price.output;
  return Number(cost.toFixed(6));
}

function pricePer1kTokens(
  provider: "glm" | "deepseek",
  model: string
): {
  input: number;
  output: number;
} {
  const normalized = model.toLowerCase();
  if (provider === "deepseek") {
    if (normalized.includes("pro")) {
      return { input: 0.000435, output: 0.00087 };
    }

    return { input: 0.00014, output: 0.00028 };
  }

  return { input: 0.0003, output: 0.0009 };
}

function providerErrorMessage(provider: string, status: number, message?: string): string {
  return `${provider} provider failed with HTTP ${status}${message ? `: ${message}` : ""}`;
}
