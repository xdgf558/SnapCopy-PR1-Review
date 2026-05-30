import { canConsumeQuota, consumeQuota, dailyLimitForPlan, getUsage } from "./quota";
import { monthlyLimitForPlan, canConsumeMonthlyUnit, currentYearMonth } from "./monthlyQuota";
import type {
  ActiveCaptionStrategy,
  CloudCaptionRequest,
  CloudVisionRequest,
  ContributionStorageMode,
  MonthlyQuotaResult,
  MonthlyUsageStatusResponse,
  Plan,
  SceneRecognitionRecordRequest,
  TrainingContributionConsentRequest,
  TrainingContributionSampleRequest,
  UserFeedbackRecordRequest,
  UsageStatusResponse
} from "../types/api";
import type { TrainingImageStorageResult } from "./r2Store";

export type D1Env = {
  DB?: D1Database;
};

type CloudQuotaResult = {
  allowed: boolean;
  remainingQuota: number;
  duplicateRequest: boolean;
};

type CloudRequestLogStatus = "success" | "api_error" | "timeout" | "quota_exceeded";

type MonthlyCostSummaryRow = {
  total_cost: number | null;
  request_count: number;
};

type GlobalCostSummaryRow = {
  daily_cost: number | null;
  monthly_cost: number | null;
};

export type MonthlyCostSummary = {
  totalCost: number;
  requestCount: number;
  avgCost: number;
};

export type GlobalCostSummary = {
  dailyCost: number;
  monthlyCost: number;
};

export type CloudRequestLogParams = {
  appUserId: string;
  requestId: string;
  plan: Plan;
  provider: string;
  model: string;
  status: CloudRequestLogStatus;
  errorCode?: string | null;
  inputTokens?: number | null;
  outputTokens?: number | null;
  estimatedCostUsd?: number | null;
  cloudUnitsUsed?: number;
  remainingQuota?: number;
  sceneJson?: string | null;
  userPreferenceJson?: string | null;
  imageUploadEnabled?: boolean;
  locale?: string;
  targetPlatform?: string;
  createdAt?: Date;
};

type ExistingRequestRow = {
  status: string;
  remaining_quota: number;
  usage_date?: string;
  feature_type?: string;
};

type UsageRow = {
  used_count: number;
};

type StrategyRow = {
  strategy_json: string;
};

const cloudCaptionFeature = "captionDeepUnderstanding";
const cloudVisionFeature = "imageUnderstanding";

type CloudMeteredRequest = Pick<
  CloudCaptionRequest | CloudVisionRequest,
  | "appUserId"
  | "requestId"
  | "featureType"
  | "clientAppVersion"
  | "clientBuild"
  | "sceneJson"
  | "userPreferenceJson"
  | "imageUploadEnabled"
  | "locale"
  | "targetPlatform"
>;

function normalizeCloudFeature(
  featureType?: string,
  plan?: Plan,
  clientAppVersion?: string,
  clientBuild?: string,
  defaultFeature = cloudCaptionFeature
): string {
  const baseFeature = !featureType || featureType === "cloudCaption" ? defaultFeature : featureType;
  const buildKey = normalizedBuildKey(clientAppVersion, clientBuild);

  if (plan === "beta" && buildKey) {
    return `${baseFeature}:testBuild:${buildKey}`;
  }

  return baseFeature;
}

function normalizedBuildKey(clientAppVersion?: string, clientBuild?: string): string | undefined {
  if (!clientBuild) {
    return undefined;
  }

  const version = (clientAppVersion ?? "unknown").replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 24);
  const build = clientBuild.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 24);
  if (!build) {
    return undefined;
  }

  return `${version}_${build}`;
}

export function hasD1(env: D1Env): env is { DB: D1Database } {
  return Boolean(env.DB);
}

/* @deprecated 阶段 2 切换为 getMonthlyUsageStatus */
export async function getUsageStatusFromStore(
  env: D1Env,
  appUserId: string,
  plan: Plan,
  clientAppVersion?: string,
  clientBuild?: string
): Promise<UsageStatusResponse> {
  const dailyLimit = dailyLimitForPlan(plan);
  const featureType = normalizeCloudFeature(cloudCaptionFeature, plan, clientAppVersion, clientBuild);

  if (!hasD1(env)) {
    const usage = getUsage(appUserId);
    return {
      plan,
      dailyLimit,
      usedToday: usage.usedToday,
      remainingQuota: Math.max(0, dailyLimit - usage.usedToday),
      monthlyLimit: dailyLimit,
      usedThisMonth: usage.usedToday,
      remainingMonthlyUnits: Math.max(0, dailyLimit - usage.usedToday)
    };
  }

  const now = new Date();
  const usageDate = usageDateString(now);
  await upsertAppUser(env.DB, appUserId, plan, now);

  const row = await env.DB.prepare(
    `SELECT used_count FROM daily_usage
     WHERE app_user_id = ? AND usage_date = ? AND feature_type = ?`
  )
    .bind(appUserId, usageDate, featureType)
    .first<UsageRow>();

  const usedToday = row?.used_count ?? 0;
  return {
    plan,
    dailyLimit,
    usedToday,
    remainingQuota: Math.max(0, dailyLimit - usedToday),
    monthlyLimit: dailyLimit,
    usedThisMonth: usedToday,
    remainingMonthlyUnits: Math.max(0, dailyLimit - usedToday)
  };
}

/* @deprecated 阶段 2 切换为 consumeMonthlyCloudUnit */
export async function consumeCloudCaptionQuota(
  env: D1Env,
  input: CloudCaptionRequest,
  plan: Plan,
  provider: string,
  model: string
): Promise<CloudQuotaResult> {
  return consumeCloudQuota(env, input, plan, provider, model, cloudCaptionFeature);
}

export async function consumeCloudVisionQuota(
  env: D1Env,
  input: CloudVisionRequest,
  plan: Plan,
  provider: string,
  model: string
): Promise<CloudQuotaResult> {
  return consumeCloudQuota(env, input, plan, provider, model, cloudVisionFeature);
}

async function consumeCloudQuota(
  env: D1Env,
  input: CloudMeteredRequest,
  plan: Plan,
  provider: string,
  model: string,
  defaultFeature: string
): Promise<CloudQuotaResult> {
  if (!hasD1(env)) {
    if (!canConsumeQuota(input.appUserId, input.requestId, plan)) {
      return {
        allowed: false,
        remainingQuota: 0,
        duplicateRequest: false
      };
    }

    return {
      allowed: true,
      remainingQuota: consumeQuota(input.appUserId, input.requestId, plan),
      duplicateRequest: false
    };
  }

  const now = new Date();
  const usageDate = usageDateString(now);
  const featureType = normalizeCloudFeature(
    input.featureType,
    plan,
    input.clientAppVersion,
    input.clientBuild,
    defaultFeature
  );
  const dailyLimit = dailyLimitForPlan(plan);
  await upsertAppUser(env.DB, input.appUserId, plan, now);

  const existing = await env.DB.prepare(
    `SELECT status, remaining_quota FROM cloud_request_logs WHERE request_id = ?`
  )
    .bind(input.requestId)
    .first<ExistingRequestRow>();

  if (existing) {
    return {
      allowed: existing.status !== "quota_exceeded",
      remainingQuota: existing.remaining_quota,
      duplicateRequest: true
    };
  }

  const row = await env.DB.prepare(
    `SELECT used_count FROM daily_usage
     WHERE app_user_id = ? AND usage_date = ? AND feature_type = ?`
  )
    .bind(input.appUserId, usageDate, featureType)
    .first<UsageRow>();

  const usedToday = row?.used_count ?? 0;
  if (usedToday >= dailyLimit) {
    await insertCloudRequestLog(env.DB, input, {
      usageDate,
      plan,
      provider,
      model,
      status: "quota_exceeded",
      remainingQuota: 0,
      now,
      featureType
    });
    return {
      allowed: false,
      remainingQuota: 0,
      duplicateRequest: false
    };
  }

  const newUsedCount = usedToday + 1;
  const remainingQuota = Math.max(0, dailyLimit - newUsedCount);

  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO daily_usage (app_user_id, usage_date, feature_type, plan, used_count, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(app_user_id, usage_date, feature_type)
       DO UPDATE SET
         plan = excluded.plan,
         used_count = excluded.used_count,
         updated_at = excluded.updated_at`
    ).bind(input.appUserId, usageDate, featureType, plan, newUsedCount, now.toISOString()),
    cloudRequestLogStatement(env.DB, input, {
      usageDate,
      plan,
      provider,
      model,
      status: "accepted",
      remainingQuota,
      now,
      featureType
    })
  ]);

  return {
    allowed: true,
    remainingQuota,
    duplicateRequest: false
  };
}

/* @deprecated 阶段 2 切换为 refundMonthlyCloudUnit */
export async function refundCloudCaptionQuota(
  env: D1Env,
  input: CloudCaptionRequest
): Promise<void> {
  await refundCloudQuota(env, input);
}

export async function refundCloudVisionQuota(
  env: D1Env,
  input: CloudVisionRequest
): Promise<void> {
  await refundCloudQuota(env, input);
}

async function refundCloudQuota(env: D1Env, input: CloudMeteredRequest): Promise<void> {
  if (!hasD1(env)) {
    return;
  }

  const existing = await env.DB.prepare(
    `SELECT status, remaining_quota, usage_date, feature_type
     FROM cloud_request_logs
     WHERE request_id = ?`
  )
    .bind(input.requestId)
    .first<ExistingRequestRow>();

  if (!existing || existing.status !== "accepted" || !existing.usage_date || !existing.feature_type) {
    return;
  }

  const refundedRemainingQuota = existing.remaining_quota + 1;
  await env.DB.batch([
    env.DB.prepare(
      `UPDATE daily_usage
       SET
         used_count = CASE WHEN used_count > 0 THEN used_count - 1 ELSE 0 END,
         updated_at = ?
       WHERE app_user_id = ? AND usage_date = ? AND feature_type = ?`
    ).bind(new Date().toISOString(), input.appUserId, existing.usage_date, existing.feature_type),
    env.DB.prepare(
      `UPDATE cloud_request_logs
       SET status = ?, remaining_quota = ?
       WHERE request_id = ?`
    ).bind("provider_error", refundedRemainingQuota, input.requestId)
  ]);
}

export async function recordContributionConsent(
  env: D1Env,
  input: TrainingContributionConsentRequest
): Promise<ContributionStorageMode> {
  if (!hasD1(env)) {
    return "metadata-only-mock";
  }

  const receivedAt = new Date();
  await upsertAppUser(env.DB, input.appUserId, "beta", receivedAt);
  await env.DB.prepare(
    `INSERT INTO training_contribution_consents (
       consent_id, app_user_id, kind, decision, scope, privacy_policy_version,
       locale, created_at, received_at
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(consent_id)
     DO UPDATE SET
       decision = excluded.decision,
       scope = excluded.scope,
       privacy_policy_version = excluded.privacy_policy_version,
       locale = excluded.locale,
       received_at = excluded.received_at`
  )
    .bind(
      input.consentId,
      input.appUserId,
      input.kind,
      input.decision,
      input.scope,
      input.privacyPolicyVersion,
      input.locale,
      input.createdAt,
      receivedAt.toISOString()
    )
    .run();

  return "d1-metadata-only";
}

export async function recordContributionSample(
  env: D1Env,
  input: TrainingContributionSampleRequest,
  imageStorage?: TrainingImageStorageResult
): Promise<ContributionStorageMode> {
  if (!hasD1(env)) {
    return "metadata-only-mock";
  }

  const receivedAt = new Date();
  const storage = imageStorage ?? {
    storageMode: "d1-metadata-only" as const,
    objectKey: null,
    mimeType: null,
    width: input.imageWidth ?? null,
    height: input.imageHeight ?? null,
    byteSize: null,
    sha256: input.imageSha256 ?? null,
    privacyRedactionStatus: "metadata_only"
  };
  await upsertAppUser(env.DB, input.appUserId, "beta", receivedAt);
  await env.DB.prepare(
    `INSERT INTO training_contribution_samples (
       sample_id, app_user_id, consent_id, kind, source, privacy_policy_version,
       locale, target_platform, scene, scene_confidence, scene_tags_json,
       scene_json, caption_text, caption_was_edited, image_upload_enabled,
       original_photo_retention, notes, created_at, received_at, review_status,
       r2_object_key, image_mime_type, image_width, image_height, image_byte_size,
       image_sha256, privacy_redaction_status
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(sample_id)
     DO NOTHING`
  )
    .bind(
      input.sampleId,
      input.appUserId,
      input.consentId,
      input.kind,
      input.source,
      input.privacyPolicyVersion,
      input.locale,
      input.targetPlatform ?? null,
      input.scene ?? null,
      input.sceneConfidence ?? null,
      JSON.stringify(input.sceneTags ?? []),
      input.sceneJson ?? null,
      input.captionText ?? null,
      input.captionWasEdited ? 1 : 0,
      input.imageUploadEnabled ? 1 : 0,
      input.originalPhotoRetention,
      input.notes ?? null,
      input.createdAt,
      receivedAt.toISOString(),
      "pending",
      storage.objectKey,
      storage.mimeType,
      storage.width,
      storage.height,
      storage.byteSize,
      storage.sha256,
      storage.privacyRedactionStatus
    )
    .run();

  return storage.storageMode;
}

export async function recordSceneRecognition(
  env: D1Env,
  input: SceneRecognitionRecordRequest
): Promise<"d1" | "disabled"> {
  if (!hasD1(env)) {
    return "disabled";
  }

  await upsertAppUser(env.DB, input.appUserId, "beta", new Date());
  await env.DB.prepare(
    `INSERT INTO scene_recognition_records (
       record_id, app_user_id, sample_id, request_id, source, predicted_scene,
       top3_scenes_json, user_selected_scene, was_user_correction_needed,
       confidence, scene_json, latency_ms, image_width, image_height, created_at
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(record_id)
     DO NOTHING`
  )
    .bind(
      input.recordId,
      input.appUserId,
      input.sampleId ?? null,
      input.requestId ?? null,
      input.source,
      input.predictedScene ?? null,
      JSON.stringify(input.top3Scenes ?? []),
      input.userSelectedScene ?? null,
      input.wasUserCorrectionNeeded ? 1 : 0,
      input.confidence ?? null,
      input.sceneJson ?? null,
      input.latencyMs ?? null,
      input.imageWidth ?? null,
      input.imageHeight ?? null,
      input.createdAt
    )
    .run();

  return "d1";
}

export async function recordUserFeedback(
  env: D1Env,
  input: UserFeedbackRecordRequest
): Promise<"d1" | "disabled"> {
  if (!hasD1(env)) {
    return "disabled";
  }

  await upsertAppUser(env.DB, input.appUserId, "beta", new Date());
  await env.DB.prepare(
    `INSERT INTO user_feedback_records (
       feedback_id, app_user_id, sample_id, caption_text_hash, action,
       reward_score, scene, locale, target_platform, metadata_json, created_at
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(feedback_id)
     DO NOTHING`
  )
    .bind(
      input.feedbackId,
      input.appUserId,
      input.sampleId ?? null,
      input.captionTextHash ?? null,
      input.action,
      input.rewardScore ?? rewardScoreForFeedback(input),
      input.scene ?? null,
      input.locale ?? null,
      input.targetPlatform ?? null,
      JSON.stringify(input.metadata ?? {}),
      input.createdAt
    )
    .run();

  return "d1";
}

export async function loadActiveCaptionStrategy(
  env: D1Env,
  input: CloudCaptionRequest
): Promise<ActiveCaptionStrategy | undefined> {
  if (!hasD1(env)) {
    return undefined;
  }

  const scene = extractSceneFromSceneJson(input.sceneJson);
  const locale = input.locale || "unknown";
  const targetPlatform = input.targetPlatform || "general";
  const row = await env.DB.prepare(
    `SELECT strategy_json
     FROM caption_strategy_candidates
     WHERE status = 'active'
       AND (scene = ? OR scene IS NULL)
       AND (locale = ? OR locale IS NULL)
       AND (target_platform = ? OR target_platform IS NULL)
     ORDER BY
       (CASE WHEN scene = ? THEN 1 ELSE 0 END) +
       (CASE WHEN locale = ? THEN 1 ELSE 0 END) +
       (CASE WHEN target_platform = ? THEN 1 ELSE 0 END) DESC,
       created_at DESC
     LIMIT 1`
  )
    .bind(scene, locale, targetPlatform, scene, locale, targetPlatform)
    .first<StrategyRow>();

  if (!row?.strategy_json) {
    return undefined;
  }

  try {
    return JSON.parse(row.strategy_json) as ActiveCaptionStrategy;
  } catch {
    return undefined;
  }
}

async function upsertAppUser(
  db: D1Database,
  appUserId: string,
  plan: Plan,
  now: Date
): Promise<void> {
  const timestamp = now.toISOString();
  await db
    .prepare(
      `INSERT INTO app_users (app_user_id, current_plan, first_seen_at, last_seen_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(app_user_id)
       DO UPDATE SET
         current_plan = excluded.current_plan,
         last_seen_at = excluded.last_seen_at`
    )
    .bind(appUserId, plan, timestamp, timestamp)
    .run();
}

async function insertCloudRequestLog(
  db: D1Database,
  input: CloudMeteredRequest,
  meta: CloudRequestLogMeta
): Promise<void> {
  await cloudRequestLogStatement(db, input, meta).run();
}

function cloudRequestLogStatement(
  db: D1Database,
  input: CloudMeteredRequest,
  meta: CloudRequestLogMeta
): D1PreparedStatement {
  return db
    .prepare(
      `INSERT INTO cloud_request_logs (
         request_id, app_user_id, usage_date, feature_type, plan, provider, model,
         status, remaining_quota, scene_json_size, preference_json_size,
         image_upload_enabled, locale, target_platform, created_at
       )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(request_id)
       DO NOTHING`
    )
    .bind(
      input.requestId,
      input.appUserId,
      meta.usageDate,
      meta.featureType,
      meta.plan,
      meta.provider,
      meta.model,
      meta.status,
      meta.remainingQuota,
      byteLength(input.sceneJson ?? ""),
      byteLength(input.userPreferenceJson ?? ""),
      input.imageUploadEnabled ? 1 : 0,
      input.locale,
      input.targetPlatform,
      meta.now.toISOString()
    );
}

function usageDateString(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function byteLength(value: string): number {
  return new TextEncoder().encode(value).byteLength;
}

function extractSceneFromSceneJson(sceneJson: string): string {
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

function rewardScoreForFeedback(input: UserFeedbackRecordRequest): number | null {
  if (input.action === "rating" && input.rating) {
    const ratingReward: Record<number, number> = {
      1: -1,
      2: -0.4,
      3: 0.1,
      4: 0.6,
      5: 1
    };
    return ratingReward[input.rating] ?? null;
  }

  const actionReward: Record<UserFeedbackRecordRequest["action"], number | null> = {
    rating: null,
    copyCaption: 0.7,
    shareCaption: 0.9,
    saveCaption: 0.6,
    regenerate: -0.4,
    deleteCaption: -0.6,
    markExternalGoodFeedback: 1.2
  };

  return actionReward[input.action] ?? null;
}

type CloudRequestLogMeta = {
  usageDate: string;
  plan: Plan;
  provider: string;
  model: string;
  status: "accepted" | "quota_exceeded" | "provider_error";
  remainingQuota: number;
  now: Date;
  featureType: string;
};

export async function getMonthlyUsageStatus(
  env: D1Env,
  appUserId: string,
  plan: Plan
): Promise<MonthlyUsageStatusResponse> {
  const limit = monthlyLimitForPlan(plan);
  if (!hasD1(env)) {
    return { plan, monthlyLimit: limit, usedThisMonth: 0, remainingMonthlyUnits: limit };
  }

  const yearMonth = currentYearMonth();
  await upsertAppUser(env.DB, appUserId, plan, new Date());
  const row = await env.DB.prepare(
    "SELECT used_units FROM monthly_usage WHERE app_user_id = ? AND year_month = ?"
  ).bind(appUserId, yearMonth).first<{ used_units: number }>();
  const used = row?.used_units ?? 0;
  return {
    plan,
    monthlyLimit: limit,
    usedThisMonth: used,
    remainingMonthlyUnits: Math.max(0, limit - used)
  };
}

export async function consumeMonthlyCloudUnit(
  env: D1Env,
  input: {
    appUserId: string;
    requestId: string;
    sceneJson: string;
    userPreferenceJson?: string | null;
    targetPlatform: string;
    locale: string;
    plan: Plan;
    provider: string;
    model: string;
    imageUploadEnabled: boolean;
  }
): Promise<MonthlyQuotaResult> {
  if (!hasD1(env)) {
    return {
      allowed: true,
      remainingUnits: monthlyLimitForPlan(input.plan) - 1,
      duplicateRequest: false
    };
  }

  const yearMonth = currentYearMonth();
  const now = new Date();
  await upsertAppUser(env.DB, input.appUserId, input.plan, now);

  const existing = await env.DB.prepare(
    "SELECT status, remaining_quota FROM cloud_request_logs WHERE request_id = ?"
  ).bind(input.requestId).first<{ status: string; remaining_quota: number }>();
  if (existing) {
    return {
      allowed: existing.status !== "quota_exceeded",
      remainingUnits: existing.remaining_quota,
      duplicateRequest: true
    };
  }

  const row = await env.DB.prepare(
    "SELECT used_units FROM monthly_usage WHERE app_user_id = ? AND year_month = ?"
  ).bind(input.appUserId, yearMonth).first<{ used_units: number }>();
  const used = row?.used_units ?? 0;
  if (!canConsumeMonthlyUnit(used, input.plan)) {
    await env.DB.prepare(
      `INSERT INTO cloud_request_logs
         (request_id, app_user_id, usage_date, feature_type, plan, provider, model,
          status, remaining_quota, scene_json_size, preference_json_size,
          image_upload_enabled, locale, target_platform, created_at,
          cost_usd, cloud_units_used, unit_type)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(request_id) DO NOTHING`
    ).bind(
      input.requestId,
      input.appUserId,
      yearMonth + "-01",
      "cloud_enhancement",
      input.plan,
      input.provider,
      input.model,
      "quota_exceeded",
      0,
      byteLength(input.sceneJson),
      byteLength(input.userPreferenceJson ?? ""),
      input.imageUploadEnabled ? 1 : 0,
      input.locale,
      input.targetPlatform,
      now.toISOString(),
      null,
      0,
      "cloud_enhancement"
    ).run();
    return { allowed: false, remainingUnits: 0, duplicateRequest: false };
  }

  const newUsed = used + 1;
  const remaining = Math.max(0, monthlyLimitForPlan(input.plan) - newUsed);
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO monthly_usage (app_user_id, year_month, plan, used_units, updated_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(app_user_id, year_month)
       DO UPDATE SET plan = excluded.plan, used_units = excluded.used_units, updated_at = excluded.updated_at`
    ).bind(input.appUserId, yearMonth, input.plan, newUsed, now.toISOString()),
    env.DB.prepare(
      `INSERT INTO cloud_request_logs
         (request_id, app_user_id, usage_date, feature_type, plan, provider, model,
          status, remaining_quota, scene_json_size, preference_json_size,
          image_upload_enabled, locale, target_platform, created_at,
          cost_usd, cloud_units_used, unit_type)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(request_id) DO NOTHING`
    ).bind(
      input.requestId,
      input.appUserId,
      yearMonth + "-01",
      "cloud_enhancement",
      input.plan,
      input.provider,
      input.model,
      "accepted",
      remaining,
      byteLength(input.sceneJson),
      byteLength(input.userPreferenceJson ?? ""),
      input.imageUploadEnabled ? 1 : 0,
      input.locale,
      input.targetPlatform,
      now.toISOString(),
      null,
      1,
      "cloud_enhancement"
    )
  ]);
  return { allowed: true, remainingUnits: remaining, duplicateRequest: false };
}

export async function refundMonthlyCloudUnit(env: D1Env, requestId: string): Promise<void> {
  if (!hasD1(env)) return;
  const existing = await env.DB.prepare(
    "SELECT status, remaining_quota, app_user_id FROM cloud_request_logs WHERE request_id = ?"
  ).bind(requestId).first<{ status: string; remaining_quota: number; app_user_id: string }>();
  if (!existing || existing.status !== "accepted") return;
  const yearMonth = currentYearMonth();
  await env.DB.batch([
    env.DB.prepare(
      "UPDATE monthly_usage SET used_units = CASE WHEN used_units > 0 THEN used_units - 1 ELSE 0 END, updated_at = ? WHERE app_user_id = ? AND year_month = ?"
    ).bind(new Date().toISOString(), existing.app_user_id, yearMonth),
    env.DB.prepare(
      "UPDATE cloud_request_logs SET status = ?, remaining_quota = ? WHERE request_id = ?"
    ).bind("provider_error", existing.remaining_quota + 1, requestId)
  ]);
}

export async function logCloudRequest(env: D1Env, params: CloudRequestLogParams): Promise<void> {
  if (!hasD1(env)) {
    return;
  }

  const now = params.createdAt ?? new Date();
  await upsertAppUser(env.DB, params.appUserId, params.plan, now);
  await env.DB.prepare(
    `INSERT INTO cloud_request_logs (
       request_id, app_user_id, usage_date, feature_type, plan, provider, model,
       status, remaining_quota, scene_json_size, preference_json_size,
       image_upload_enabled, locale, target_platform, created_at,
       cost_usd, cloud_units_used, unit_type, input_tokens, output_tokens, error_code
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(request_id)
     DO UPDATE SET
       plan = excluded.plan,
       provider = excluded.provider,
       model = excluded.model,
       status = excluded.status,
       remaining_quota = excluded.remaining_quota,
       scene_json_size = excluded.scene_json_size,
       preference_json_size = excluded.preference_json_size,
       image_upload_enabled = excluded.image_upload_enabled,
       locale = excluded.locale,
       target_platform = excluded.target_platform,
       cost_usd = excluded.cost_usd,
       cloud_units_used = excluded.cloud_units_used,
       unit_type = excluded.unit_type,
       input_tokens = excluded.input_tokens,
       output_tokens = excluded.output_tokens,
       error_code = excluded.error_code`
  )
    .bind(
      params.requestId,
      params.appUserId,
      currentUsageDateForCostLog(now),
      "cloud_enhancement",
      params.plan,
      params.provider,
      params.model,
      params.status,
      params.remainingQuota ?? 0,
      byteLength(params.sceneJson ?? ""),
      byteLength(params.userPreferenceJson ?? ""),
      params.imageUploadEnabled ? 1 : 0,
      params.locale ?? "unknown",
      params.targetPlatform ?? "general",
      now.toISOString(),
      params.estimatedCostUsd ?? null,
      params.cloudUnitsUsed ?? (params.status === "success" ? 1 : 0),
      "cloud_enhancement",
      params.inputTokens ?? 0,
      params.outputTokens ?? 0,
      params.errorCode ?? null
    )
    .run();
}

export async function getMonthlyCostSummary(
  env: D1Env,
  appUserId: string,
  billingMonth: string
): Promise<MonthlyCostSummary> {
  if (!hasD1(env)) {
    return { totalCost: 0, requestCount: 0, avgCost: 0 };
  }

  const row = await env.DB.prepare(
    `SELECT SUM(cost_usd) AS total_cost, COUNT(*) AS request_count
     FROM cloud_request_logs
     WHERE app_user_id = ?
       AND strftime('%Y-%m', created_at) = ?
       AND status = 'success'`
  )
    .bind(appUserId, billingMonth)
    .first<MonthlyCostSummaryRow>();

  const totalCost = Number(row?.total_cost ?? 0);
  const requestCount = Number(row?.request_count ?? 0);
  return {
    totalCost,
    requestCount,
    avgCost: requestCount > 0 ? totalCost / requestCount : 0
  };
}

export async function getGlobalCostSummary(env: D1Env, now = new Date()): Promise<GlobalCostSummary> {
  if (!hasD1(env)) {
    return { dailyCost: 0, monthlyCost: 0 };
  }

  const today = now.toISOString().slice(0, 10);
  const month = now.toISOString().slice(0, 7);
  const row = await env.DB.prepare(
    `SELECT
       SUM(CASE WHEN date(created_at) = ? THEN COALESCE(cost_usd, 0) ELSE 0 END) AS daily_cost,
       SUM(CASE WHEN strftime('%Y-%m', created_at) = ? THEN COALESCE(cost_usd, 0) ELSE 0 END) AS monthly_cost
     FROM cloud_request_logs
     WHERE status = 'success'`
  )
    .bind(today, month)
    .first<GlobalCostSummaryRow>();

  return {
    dailyCost: Number(row?.daily_cost ?? 0),
    monthlyCost: Number(row?.monthly_cost ?? 0)
  };
}

function currentUsageDateForCostLog(date: Date): string {
  return date.toISOString().slice(0, 10);
}
