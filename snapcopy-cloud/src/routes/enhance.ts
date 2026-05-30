import { jsonResponse, errorResponse } from "../lib/response";
import { AiProviderError, enhanceCaption, type AiProviderEnv } from "../lib/aiProvider";
import { applyCostProtectionAfterSuccess, strategyForCloudRequest } from "../lib/costProtection";
import { logCloudRequest } from "../lib/d1Store";
import { cloudEnhancementUnavailableResponse, isCloudEnhancementAvailable } from "../lib/featureFlags";
import { checkQuota, commitReservedUnit, refundReservedUnit, reserveUnit } from "../lib/monthlyQuota";
import type { CostConfigEnv } from "../config/cost-config";
import type { CloudEnhancementRequest, CloudEnhancementResponse, Plan } from "../types/api";

type Env = AiProviderEnv & CostConfigEnv & {
  CLOUD_ENHANCEMENT_ENABLED?: string;
  DEFAULT_PLAN?: Plan;
  DEFAULT_PROVIDER?: string;
  DB?: D1Database;
};

type EnhanceLogContext = {
  appUserId: string;
  requestId: string;
  plan: Plan;
  provider: string;
  model: string;
  sceneJson: string;
  userPreferenceJson: string;
  imageUploadEnabled: boolean;
  locale: string;
  targetPlatform: string;
  remainingQuota: number;
};

export async function handleEnhance(request: Request, env: Env): Promise<Response> {
  let logContext: EnhanceLogContext | null = null;
  let reservedUnitRequestId: string | null = null;

  try {
    if (!(await isCloudEnhancementAvailable(env))) {
      return cloudEnhancementUnavailableResponse();
    }

    const input = await parseOptionalJsonBody<CloudEnhancementRequest>(request);
    const scene = resolveScene(input.sceneJson);
    const requestId = normalizedRequestId(input.requestId);
    const appUserId = normalizedAppUserId(input.appUserId);
    const plan = resolvePlan(input.plan, env.DEFAULT_PLAN);
    const strategy = strategyForCloudRequest(plan, appUserId);
    const sceneJson = input.sceneJson ?? "{}";
    const userPreferenceJson = userPreferenceToJson(input.userPreference);
    const locale = input.locale ?? "unknown";
    const targetPlatform = input.targetPlatform ?? "general";
    logContext = {
      appUserId,
      requestId,
      plan,
      provider: env.DEFAULT_PROVIDER ?? "unresolved",
      model: strategy.modelName,
      sceneJson,
      userPreferenceJson,
      imageUploadEnabled: Boolean(input.imagePayload),
      locale,
      targetPlatform,
      remainingQuota: 0
    };

    const quotaCheck = await checkQuota(env, {
      appUserId,
      requestId,
      plan
    });
    if (!quotaCheck.allowed) {
      logContext.remainingQuota = quotaCheck.remainingUnits;
      await safeLogCloudRequest(env, {
        ...logContext,
        status: "quota_exceeded",
        errorCode: "quota_exceeded",
        cloudUnitsUsed: 0,
        inputTokens: 0,
        outputTokens: 0,
        estimatedCostUsd: null,
        remainingQuota: quotaCheck.remainingUnits
      });
      return errorResponse("quota_exceeded", "Monthly cloud enhancement quota has been used.", 429);
    }

    if (quotaCheck.duplicateRequest) {
      return jsonResponse(
        idempotentDuplicateResponse({
          requestId,
          scene,
          provider: logContext.provider,
          model: logContext.model,
          remainingMonthlyUnits: quotaCheck.remainingUnits
        })
      );
    }

    const reservation = await reserveUnit(env, {
      appUserId,
      requestId,
      plan,
      provider: logContext.provider,
      model: logContext.model,
      sceneJson,
      userPreferenceJson,
      imageUploadEnabled: Boolean(input.imagePayload),
      locale,
      targetPlatform
    });
    logContext.remainingQuota = reservation.remainingUnits;
    if (!reservation.allowed) {
      await safeLogCloudRequest(env, {
        ...logContext,
        status: "quota_exceeded",
        errorCode: "quota_exceeded",
        cloudUnitsUsed: 0,
        inputTokens: 0,
        outputTokens: 0,
        estimatedCostUsd: null,
        remainingQuota: reservation.remainingUnits
      });
      return errorResponse("quota_exceeded", "Monthly cloud enhancement quota has been used.", 429);
    }

    if (reservation.duplicateRequest) {
      return jsonResponse(
        idempotentDuplicateResponse({
          requestId,
          scene,
          provider: logContext.provider,
          model: logContext.model,
          remainingMonthlyUnits: reservation.remainingUnits
        })
      );
    }
    reservedUnitRequestId = requestId;

    const result = await enhanceCaption({
      env,
      imagePayload: input.imagePayload,
      sceneJson,
      userPreference: input.userPreference,
      targetPlatform,
      locale,
      strategy
    });
    logContext = {
      ...logContext,
      provider: result.provider,
      model: result.model,
      remainingQuota: reservation.remainingUnits
    };

    await commitReservedUnit(env, requestId);
    reservedUnitRequestId = null;

    const cloudUnitsUsed = Math.max(1, result.cloudUnitsUsed);
    logContext.remainingQuota = reservation.remainingUnits;
    await safeLogCloudRequest(env, {
      ...logContext,
      status: "success",
      errorCode: null,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      estimatedCostUsd: result.estimatedCostUsd,
      cloudUnitsUsed,
      remainingQuota: reservation.remainingUnits
    });
    await safeApplyCostProtection(env, {
      appUserId,
      plan,
      strategy,
      estimatedCostUsd: result.estimatedCostUsd
    });

    const response: CloudEnhancementResponse = {
      captions: result.captions,
      scene,
      provider: result.provider,
      model: result.model,
      cloudUnitsUsed,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      estimatedCostUsd: result.estimatedCostUsd,
      remainingMonthlyUnits: reservation.remainingUnits,
      requestId
    };

    return jsonResponse(response);
  } catch (error) {
    if (error instanceof SyntaxError) {
      return errorResponse("invalid_json", "Request body must be valid JSON.", 400);
    }

    if (error instanceof AiProviderError) {
      const refunded = await safeRefundReservedUnit(env, reservedUnitRequestId, error);
      reservedUnitRequestId = null;
      if (!refunded) {
        await safeLogEnhanceFailure(env, logContext, error);
      }
      if (isTimeoutError(error)) {
        return errorResponse("timeout", "Cloud enhancement request timed out.", 504);
      }

      return errorResponse("provider_error", error.message, 502);
    }

    const refunded = await safeRefundReservedUnit(env, reservedUnitRequestId, error);
    reservedUnitRequestId = null;
    if (!refunded) {
      await safeLogEnhanceFailure(env, logContext, error);
    }
    return errorResponse("internal_error", "Cloud enhancement failed.", 500);
  }
}

function idempotentDuplicateResponse(input: {
  requestId: string;
  scene: string | null;
  provider: string;
  model: string;
  remainingMonthlyUnits: number;
}): CloudEnhancementResponse {
  return {
    captions: [],
    scene: input.scene,
    provider: input.provider,
    model: input.model,
    cloudUnitsUsed: 0,
    inputTokens: 0,
    outputTokens: 0,
    estimatedCostUsd: null,
    remainingMonthlyUnits: input.remainingMonthlyUnits,
    requestId: input.requestId
  };
}

async function safeLogEnhanceFailure(env: Env, context: EnhanceLogContext | null, error: unknown): Promise<void> {
  if (!context) {
    return;
  }

  const isTimeout =
    error instanceof AiProviderError && isTimeoutError(error);
  await safeLogCloudRequest(env, {
    ...context,
    status: isTimeout ? "timeout" : "api_error",
    errorCode: errorCodeForEnhanceFailure(error),
    inputTokens: 0,
    outputTokens: 0,
    estimatedCostUsd: null,
    cloudUnitsUsed: 0
  });
}

async function safeRefundReservedUnit(
  env: Env,
  requestId: string | null,
  error: unknown
): Promise<boolean> {
  if (!requestId) {
    return false;
  }

  const status = error instanceof AiProviderError && isTimeoutError(error) ? "timeout" : "api_error";
  try {
    await refundReservedUnit(env, requestId, status, errorCodeForEnhanceFailure(error));
    return true;
  } catch (refundError) {
    const message = refundError instanceof Error ? refundError.message : "unknown";
    console.warn(`[QUOTA_REFUND_WARN] ${message}`);
    return false;
  }
}

async function safeApplyCostProtection(
  env: Env,
  input: Parameters<typeof applyCostProtectionAfterSuccess>[1]
): Promise<void> {
  try {
    await applyCostProtectionAfterSuccess(env, input);
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown";
    console.warn(`[COST_PROTECTION_WARN] ${message}`);
  }
}

async function safeLogCloudRequest(
  env: Env,
  params: Parameters<typeof logCloudRequest>[1]
): Promise<void> {
  try {
    await logCloudRequest(env, params);
  } catch {
    // Logging must never hide the actual enhancement response from the app.
  }
}

function errorCodeForEnhanceFailure(error: unknown): string {
  if (error instanceof AiProviderError) {
    return error.statusCode === 504 ? "timeout" : `provider_${error.statusCode}`;
  }

  return "internal_error";
}

function isTimeoutError(error: AiProviderError): boolean {
  return error.statusCode === 504 || error.message.toLowerCase().includes("timed out");
}

async function parseOptionalJsonBody<T>(request: Request): Promise<T> {
  const rawBody = await request.text();
  if (!rawBody.trim()) {
    return {} as T;
  }

  return JSON.parse(rawBody) as T;
}

function normalizedRequestId(requestId: string | undefined): string {
  if (requestId && requestId.trim()) {
    return requestId;
  }

  return crypto.randomUUID();
}

function normalizedAppUserId(appUserId: string | undefined): string {
  return appUserId?.trim() || "anonymous";
}

function resolvePlan(inputPlan: Plan | undefined, defaultPlan: Plan | undefined): Plan {
  return inputPlan ?? defaultPlan ?? "beta";
}

function userPreferenceToJson(value: CloudEnhancementRequest["userPreference"]): string {
  if (typeof value === "string") {
    return value;
  }

  return JSON.stringify(value ?? {});
}

function resolveScene(sceneJson: string | null | undefined): string | null {
  if (!sceneJson?.trim()) {
    return "unknown";
  }

  try {
    const parsed = JSON.parse(sceneJson) as Record<string, unknown>;
    const resolvedScene = parsed.resolvedScene;
    if (resolvedScene && typeof resolvedScene === "object") {
      const scene = (resolvedScene as Record<string, unknown>).scene;
      if (typeof scene === "string" && scene.trim()) {
        return scene;
      }
    }

    const primaryScene = parsed.primaryScene;
    if (typeof primaryScene === "string" && primaryScene.trim()) {
      return primaryScene;
    }

    const scene = parsed.scene;
    if (typeof scene === "string" && scene.trim()) {
      return scene;
    }
  } catch {
    return "unknown";
  }

  return "unknown";
}
