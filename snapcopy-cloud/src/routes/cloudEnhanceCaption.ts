import { jsonResponse, errorResponse } from "../lib/response";
import { makeMockCaptions } from "../lib/mockCaptions";
import { parseJsonBody, resolveEffectivePlan, validateCaptionRequest, ValidationError } from "../lib/validators";
import { consumeCloudCaptionQuota } from "../lib/d1Store";
import {
  CaptionProviderError,
  generateRealCaptions,
  modelForProvider,
  resolveCaptionProvider
} from "../providers/captionProviders";
import type { CloudCaptionRequest, CloudCaptionResponse, Plan } from "../types/api";

type Env = {
  DEFAULT_PLAN?: Plan;
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
  DB?: D1Database;
};

export async function handleCloudEnhanceCaption(request: Request, env: Env): Promise<Response> {
  try {
    const body = await parseJsonBody<CloudCaptionRequest>(request, 512_000);
    const input = validateCaptionRequest(body);
    const plan = resolveEffectivePlan(input.plan, env.DEFAULT_PLAN ?? "beta");
    input.plan = plan;
    const provider = resolveCaptionProvider(env);
    const model = modelForProvider(provider, env);

    const quota = await consumeCloudCaptionQuota(env, input, plan, provider, model);
    if (!quota.allowed) {
      return errorResponse("quota_exceeded", "Daily cloud enhancement quota has been used.", 429);
    }

    const response: CloudCaptionResponse =
      provider === "mock"
        ? {
            captions: makeMockCaptions(input),
            provider,
            model,
            inputTokens: 0,
            outputTokens: 0,
            estimatedCost: 0,
            remainingQuota: quota.remainingQuota
          }
        : {
            ...(await generateRealCaptions(input, provider, env)),
            remainingQuota: quota.remainingQuota
          };

    return jsonResponse(response);
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    if (error instanceof CaptionProviderError) {
      return errorResponse("provider_error", error.message, error.statusCode);
    }

    return errorResponse("internal_error", "Cloud caption enhancement failed.", 500);
  }
}
