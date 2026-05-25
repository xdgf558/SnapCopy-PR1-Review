import { canConsumeQuota, consumeQuota, dailyLimitForPlan, getUsage } from "./quota";
import type {
  ActiveCaptionStrategy,
  CloudCaptionRequest,
  ContributionStorageMode,
  Plan,
  TrainingContributionConsentRequest,
  TrainingContributionSampleRequest,
  UsageStatusResponse
} from "../types/api";

export type D1Env = {
  DB?: D1Database;
};

type CloudQuotaResult = {
  allowed: boolean;
  remainingQuota: number;
  duplicateRequest: boolean;
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

function normalizeCloudCaptionFeature(featureType?: string): string {
  if (!featureType || featureType === "cloudCaption") {
    return cloudCaptionFeature;
  }

  return featureType;
}

export function hasD1(env: D1Env): env is { DB: D1Database } {
  return Boolean(env.DB);
}

export async function getUsageStatusFromStore(
  env: D1Env,
  appUserId: string,
  plan: Plan
): Promise<UsageStatusResponse> {
  const dailyLimit = dailyLimitForPlan(plan);

  if (!hasD1(env)) {
    const usage = getUsage(appUserId);
    return {
      plan,
      dailyLimit,
      usedToday: usage.usedToday,
      remainingQuota: Math.max(0, dailyLimit - usage.usedToday)
    };
  }

  const now = new Date();
  const usageDate = usageDateString(now);
  await upsertAppUser(env.DB, appUserId, plan, now);

  const row = await env.DB.prepare(
    `SELECT used_count FROM daily_usage
     WHERE app_user_id = ? AND usage_date = ? AND feature_type = ?`
  )
    .bind(appUserId, usageDate, cloudCaptionFeature)
    .first<UsageRow>();

  const usedToday = row?.used_count ?? 0;
  return {
    plan,
    dailyLimit,
    usedToday,
    remainingQuota: Math.max(0, dailyLimit - usedToday)
  };
}

export async function consumeCloudCaptionQuota(
  env: D1Env,
  input: CloudCaptionRequest,
  plan: Plan,
  provider: string,
  model: string
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
  const featureType = normalizeCloudCaptionFeature(input.featureType);
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
      now
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
      now
    })
  ]);

  return {
    allowed: true,
    remainingQuota,
    duplicateRequest: false
  };
}

export async function refundCloudCaptionQuota(
  env: D1Env,
  input: CloudCaptionRequest
): Promise<void> {
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
  input: TrainingContributionSampleRequest
): Promise<ContributionStorageMode> {
  if (!hasD1(env)) {
    return "metadata-only-mock";
  }

  const receivedAt = new Date();
  await upsertAppUser(env.DB, input.appUserId, "beta", receivedAt);
  await env.DB.prepare(
    `INSERT INTO training_contribution_samples (
       sample_id, app_user_id, consent_id, kind, source, privacy_policy_version,
       locale, target_platform, scene, scene_confidence, scene_tags_json,
       scene_json, caption_text, caption_was_edited, image_upload_enabled,
       original_photo_retention, notes, created_at, received_at
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      receivedAt.toISOString()
    )
    .run();

  return "d1-metadata-only";
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
  input: CloudCaptionRequest,
  meta: CloudRequestLogMeta
): Promise<void> {
  await cloudRequestLogStatement(db, input, meta).run();
}

function cloudRequestLogStatement(
  db: D1Database,
  input: CloudCaptionRequest,
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
      normalizeCloudCaptionFeature(input.featureType),
      meta.plan,
      meta.provider,
      meta.model,
      meta.status,
      meta.remainingQuota,
      byteLength(input.sceneJson),
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

type CloudRequestLogMeta = {
  usageDate: string;
  plan: Plan;
  provider: string;
  model: string;
  status: "accepted" | "quota_exceeded" | "provider_error";
  remainingQuota: number;
  now: Date;
};
