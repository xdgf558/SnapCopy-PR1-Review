// @deprecated — 将在阶段 3 移除，请使用 /api/enhance
import { jsonResponse, errorResponse } from "../lib/response";
import { consumeCloudVisionQuota, recordSceneRecognition, refundCloudVisionQuota } from "../lib/d1Store";
import { enforceCloudVisionSecurity } from "../lib/securityGuards";
import { parseJsonBody, resolveEffectivePlan, validateVisionRequest, ValidationError } from "../lib/validators";
import {
  generateVisionUnderstanding,
  modelForVisionProvider,
  resolveVisionProvider,
  VisionProviderError,
  type VisionProviderName
} from "../providers/visionProviders";
import type { CloudVisionRequest, Plan } from "../types/api";

type Env = {
  DEFAULT_PLAN?: Plan;
  VISION_PROVIDER?: string;
  GLM_API_KEY?: string;
  GLM_MODEL?: string;
  GLM_BASE_URL?: string;
  PPQ_API_KEY?: string;
  PPQ_MODEL?: string;
  PPQ_BASE_URL?: string;
  RATE_LIMIT_USER_PER_MINUTE?: string;
  RATE_LIMIT_IP_PER_MINUTE?: string;
  MAX_NEW_USERS_PER_IP_PER_DAY?: string;
  MAX_REAL_PROVIDER_REQUESTS_PER_DAY?: string;
  SECURITY_HASH_SALT?: string;
  ALLOW_CLIENT_PLAN_OVERRIDE?: string;
  DB?: D1Database;
};

export async function handleCloudEnhanceVision(request: Request, env: Env): Promise<Response> {
  let quotaInput: CloudVisionRequest | undefined;
  let quotaRefundable = false;

  try {
    const body = await parseJsonBody<CloudVisionRequest>(request, 2_000_000);
    const input = validateVisionRequest(body);
    quotaInput = input;

    const plan = resolveEffectivePlan(
      env.ALLOW_CLIENT_PLAN_OVERRIDE === "true" ? input.plan : undefined,
      env.DEFAULT_PLAN ?? "beta"
    );
    input.plan = plan;

    const resolvedProvider = resolveVisionProvider(env);
    const security = await enforceCloudVisionSecurity(request, env, input, plan, resolvedProvider);
    if (!security.allowed) {
      return errorResponse(security.code, security.message, security.statusCode);
    }

    const provider = security.provider as VisionProviderName;
    const model = modelForVisionProvider(provider, env);
    const quota = await consumeCloudVisionQuota(env, input, plan, provider, model);
    if (!quota.allowed) {
      return errorResponse("quota_exceeded", "Daily cloud image understanding quota has been used.", 429);
    }
    quotaRefundable = provider !== "mock" && !quota.duplicateRequest;

    const startedAt = Date.now();
    const response = await generateVisionUnderstanding(input, provider, env);
    try {
      await recordSceneRecognition(env, {
        appUserId: input.appUserId,
        recordId: crypto.randomUUID(),
        requestId: input.requestId,
        source: "cloudVision",
        predictedScene: response.understanding.scene,
        top3Scenes: response.understanding.top3Scenes,
        userSelectedScene: null,
        wasUserCorrectionNeeded: false,
        confidence: response.understanding.confidence,
        sceneJson: response.sceneJson,
        latencyMs: Date.now() - startedAt,
        createdAt: new Date().toISOString()
      });
    } catch {
      // Scene logging is useful for training review, but it should never block
      // the user's cloud enhancement result.
    }
    return jsonResponse({
      ...response,
      remainingQuota: quota.remainingQuota
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    if (error instanceof VisionProviderError) {
      if (quotaInput && quotaRefundable) {
        await refundCloudVisionQuota(env, quotaInput);
      }
      return errorResponse("provider_error", error.message, error.statusCode);
    }

    return errorResponse("internal_error", "Cloud image understanding failed.", 500);
  }
}
