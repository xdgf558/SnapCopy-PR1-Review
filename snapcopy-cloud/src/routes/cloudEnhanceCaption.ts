// @deprecated — 将在阶段 3 移除，请使用 /api/enhance
import { jsonResponse, errorResponse } from "../lib/response";
import { makeMockCaptions } from "../lib/mockCaptions";
import { parseJsonBody, resolveEffectivePlan, validateCaptionRequest, ValidationError } from "../lib/validators";
import { consumeCloudCaptionQuota, loadActiveCaptionStrategy, refundCloudCaptionQuota } from "../lib/d1Store";
import { enforceCloudCaptionSecurity } from "../lib/securityGuards";
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
  RATE_LIMIT_USER_PER_MINUTE?: string;
  RATE_LIMIT_IP_PER_MINUTE?: string;
  MAX_NEW_USERS_PER_IP_PER_DAY?: string;
  MAX_REAL_PROVIDER_REQUESTS_PER_DAY?: string;
  SECURITY_HASH_SALT?: string;
  ALLOW_CLIENT_PLAN_OVERRIDE?: string;
  DB?: D1Database;
};

export async function handleCloudEnhanceCaption(request: Request, env: Env): Promise<Response> {
  let quotaInput: CloudCaptionRequest | undefined;
  let quotaRefundable = false;

  try {
    const body = await parseJsonBody<CloudCaptionRequest>(request, 512_000);
    const input = validateCaptionRequest(body);
    quotaInput = input;
    // Beta builds can temporarily mirror the app's mock entitlement so developer
    // Pro/Plus testing matches the UI. Turn this off when StoreKit server
    // validation becomes the source of truth.
    const plan = resolveEffectivePlan(
      env.ALLOW_CLIENT_PLAN_OVERRIDE === "true" ? input.plan : undefined,
      env.DEFAULT_PLAN ?? "beta"
    );
    input.plan = plan;
    const resolvedProvider = resolveCaptionProvider(env);
    const security = await enforceCloudCaptionSecurity(request, env, input, plan, resolvedProvider);
    if (!security.allowed) {
      return errorResponse(security.code, security.message, security.statusCode);
    }

    const provider = security.provider;
    const model = modelForProvider(provider, env);

    const quota = await consumeCloudCaptionQuota(env, input, plan, provider, model);
    if (!quota.allowed) {
      return errorResponse("quota_exceeded", "Daily cloud enhancement quota has been used.", 429);
    }
    quotaRefundable = provider !== "mock" && !quota.duplicateRequest;

    const activeStrategy = provider === "mock" ? undefined : await loadActiveCaptionStrategy(env, input);
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
            ...(await generateRealCaptions(input, provider, env, activeStrategy)),
            remainingQuota: quota.remainingQuota
          };

    return jsonResponse(response);
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    if (error instanceof CaptionProviderError) {
      if (quotaInput && quotaRefundable) {
        await refundCloudCaptionQuota(env, quotaInput);
      }
      return errorResponse("provider_error", error.message, error.statusCode);
    }

    return errorResponse("internal_error", "Cloud caption enhancement failed.", 500);
  }
}
