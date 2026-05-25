import { buildCaptionProviderPrompt } from "./captionPrompt";
import { parseCaptionsFromProviderText } from "./captionParser";
import type { CloudCaptionRequest, CloudCaptionResponse } from "../types/api";

export type CaptionProviderEnv = {
  DEFAULT_PROVIDER?: string;
  GEMINI_API_KEY?: string;
  GEMINI_MODEL?: string;
  DEEPSEEK_API_KEY?: string;
  DEEPSEEK_MODEL?: string;
  DEEPSEEK_BASE_URL?: string;
  DASHSCOPE_API_KEY?: string;
  QWEN_API_KEY?: string;
  QWEN_MODEL?: string;
  QWEN_BASE_URL?: string;
};

export type CaptionProviderName = "mock" | "gemini" | "deepseek" | "qwen";

type GeminiResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string;
      }>;
    };
  }>;
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
  };
  error?: {
    message?: string;
  };
};

type QwenResponse = {
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

type DeepSeekResponse = QwenResponse;

export class CaptionProviderError extends Error {
  constructor(
    message: string,
    readonly statusCode = 502
  ) {
    super(message);
    this.name = "CaptionProviderError";
  }
}

export function resolveCaptionProvider(env: CaptionProviderEnv): CaptionProviderName {
  const provider = (env.DEFAULT_PROVIDER ?? "mock").toLowerCase();
  if (provider === "gemini" || provider === "deepseek" || provider === "qwen") {
    return provider;
  }

  return "mock";
}

export function assertCaptionProviderConfigured(provider: CaptionProviderName, env: CaptionProviderEnv): void {
  if (provider === "gemini" && !env.GEMINI_API_KEY) {
    throw new CaptionProviderError("GEMINI_API_KEY is not configured.", 500);
  }

  if (provider === "deepseek" && !env.DEEPSEEK_API_KEY) {
    throw new CaptionProviderError("DEEPSEEK_API_KEY is not configured.", 500);
  }

  if (provider === "qwen" && !(env.DASHSCOPE_API_KEY || env.QWEN_API_KEY)) {
    throw new CaptionProviderError("DASHSCOPE_API_KEY or QWEN_API_KEY is not configured.", 500);
  }
}

export async function generateRealCaptions(
  input: CloudCaptionRequest,
  provider: Exclude<CaptionProviderName, "mock">,
  env: CaptionProviderEnv
): Promise<CloudCaptionResponse> {
  assertCaptionProviderConfigured(provider, env);

  if (provider === "gemini") {
    return generateGeminiCaptions(input, env);
  }

  if (provider === "deepseek") {
    return generateDeepSeekCaptions(input, env);
  }

  return generateQwenCaptions(input, env);
}

export function modelForProvider(provider: CaptionProviderName, env: CaptionProviderEnv): string {
  switch (provider) {
    case "gemini":
      return env.GEMINI_MODEL ?? "gemini-2.5-flash";
    case "deepseek":
      return env.DEEPSEEK_MODEL ?? "deepseek-v4-flash";
    case "qwen":
      return env.QWEN_MODEL ?? "qwen-plus";
    case "mock":
      return "mock-v1";
  }
}

async function generateGeminiCaptions(
  input: CloudCaptionRequest,
  env: CaptionProviderEnv
): Promise<CloudCaptionResponse> {
  const model = modelForProvider("gemini", env).replace(/^models\//, "");
  const prompt = buildCaptionProviderPrompt(input);
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": env.GEMINI_API_KEY ?? ""
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [{ text: prompt }]
        }
      ],
      generationConfig: {
        temperature: 0.85,
        topP: 0.9,
        maxOutputTokens: 1200,
        responseMimeType: "application/json"
      }
    })
  });

  const json = await response.json<GeminiResponse>();
  if (!response.ok) {
    throw new CaptionProviderError(providerErrorMessage("Gemini", response.status, json.error?.message), 502);
  }

  const text = json.candidates?.[0]?.content?.parts?.map((part) => part.text ?? "").join("\n").trim() ?? "";
  const captions = parseCaptionsOrThrow(text, "Gemini");

  return {
    captions,
    provider: "gemini",
    model,
    inputTokens: json.usageMetadata?.promptTokenCount ?? 0,
    outputTokens: json.usageMetadata?.candidatesTokenCount ?? 0,
    estimatedCost: null,
    remainingQuota: 0
  };
}

async function generateDeepSeekCaptions(
  input: CloudCaptionRequest,
  env: CaptionProviderEnv
): Promise<CloudCaptionResponse> {
  const model = modelForProvider("deepseek", env);
  const baseUrl = (env.DEEPSEEK_BASE_URL ?? "https://api.deepseek.com").replace(/\/+$/, "");
  const prompt = buildCaptionProviderPrompt(input);
  const response = await fetch(`${baseUrl}/v1/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.DEEPSEEK_API_KEY ?? ""}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content: "You write polished, specific, adult social captions. Return strict JSON only."
        },
        {
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.8,
      max_tokens: 1200,
      response_format: {
        type: "json_object"
      }
    })
  });

  const json = await response.json<DeepSeekResponse>();
  if (!response.ok) {
    throw new CaptionProviderError(providerErrorMessage("DeepSeek", response.status, json.error?.message), 502);
  }

  const text = json.choices?.[0]?.message?.content?.trim() ?? "";
  const captions = parseCaptionsOrThrow(text, "DeepSeek");

  return {
    captions,
    provider: "deepseek",
    model,
    inputTokens: json.usage?.prompt_tokens ?? 0,
    outputTokens: json.usage?.completion_tokens ?? 0,
    estimatedCost: null,
    remainingQuota: 0
  };
}

async function generateQwenCaptions(
  input: CloudCaptionRequest,
  env: CaptionProviderEnv
): Promise<CloudCaptionResponse> {
  const model = modelForProvider("qwen", env);
  const baseUrl = (env.QWEN_BASE_URL ?? "https://dashscope-intl.aliyuncs.com/compatible-mode/v1").replace(/\/+$/, "");
  const prompt = buildCaptionProviderPrompt(input);
  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.DASHSCOPE_API_KEY ?? env.QWEN_API_KEY ?? ""}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content: "You write polished, specific, adult social captions. Return strict JSON only."
        },
        {
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.85,
      max_tokens: 1200
    })
  });

  const json = await response.json<QwenResponse>();
  if (!response.ok) {
    throw new CaptionProviderError(providerErrorMessage("Qwen", response.status, json.error?.message), 502);
  }

  const text = json.choices?.[0]?.message?.content?.trim() ?? "";
  const captions = parseCaptionsOrThrow(text, "Qwen");

  return {
    captions,
    provider: "qwen",
    model,
    inputTokens: json.usage?.prompt_tokens ?? 0,
    outputTokens: json.usage?.completion_tokens ?? 0,
    estimatedCost: null,
    remainingQuota: 0
  };
}

function parseCaptionsOrThrow(text: string, providerLabel: string): string[] {
  const captions = parseCaptionsFromProviderText(text);
  if (captions.length < 3) {
    throw new CaptionProviderError(`${providerLabel} returned invalid caption JSON.`, 502);
  }

  return captions;
}

function providerErrorMessage(provider: string, status: number, message?: string): string {
  return `${provider} provider failed with HTTP ${status}${message ? `: ${message}` : ""}`;
}
