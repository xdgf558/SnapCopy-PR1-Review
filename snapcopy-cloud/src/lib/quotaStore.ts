import type { MonthlyUsageRecord, Plan } from "../types/api";

export type QuotaStoreEnv = {
  DB?: D1Database;
};

export type CloudUnitRequestLogInput = {
  appUserId: string;
  requestId: string;
  billingPeriod: string;
  plan: Plan;
  provider: string;
  model: string;
  status: "reserved" | "accepted" | "quota_exceeded";
  remainingUnits: number;
  sceneJson?: string | null;
  userPreferenceJson?: string | null;
  imageUploadEnabled?: boolean;
  locale?: string;
  targetPlatform?: string;
  cloudUnitsUsed: number;
};

export type CloudUnitRequestLogRow = {
  status: string;
  remainingQuota: number;
  cloudUnitsUsed: number;
  plan: Plan;
  usageDate: string | null;
};

type MonthlyUsageRow = {
  app_user_id: string;
  year_month: string;
  plan: Plan;
  used_units: number;
  updated_at: string;
};

type CloudRequestLogRow = {
  status: string;
  remaining_quota: number;
  cloud_units_used: number | null;
  plan: Plan;
  usage_date: string | null;
};

export function hasQuotaD1(env: QuotaStoreEnv): env is { DB: D1Database } {
  return Boolean(env.DB);
}

export async function getMonthlyUsage(
  env: QuotaStoreEnv,
  appUserId: string,
  billingPeriod: string
): Promise<MonthlyUsageRecord | null> {
  if (!hasQuotaD1(env)) {
    return null;
  }

  const row = await env.DB.prepare(
    "SELECT app_user_id, year_month, plan, used_units, updated_at FROM monthly_usage WHERE app_user_id = ? AND year_month = ?"
  )
    .bind(appUserId, billingPeriod)
    .first<MonthlyUsageRow>();

  return row ? mapMonthlyUsageRow(row) : null;
}

export async function createMonthlyUsage(
  env: QuotaStoreEnv,
  appUserId: string,
  billingPeriod: string,
  plan: Plan,
  _limit: number
): Promise<void> {
  if (!hasQuotaD1(env)) {
    return;
  }

  const now = new Date();
  await upsertAppUser(env.DB, appUserId, plan, now);
  await env.DB.prepare(
    `INSERT INTO monthly_usage (app_user_id, year_month, plan, used_units, updated_at)
     VALUES (?, ?, ?, 0, ?)
     ON CONFLICT(app_user_id, year_month)
     DO UPDATE SET plan = excluded.plan, updated_at = excluded.updated_at`
  )
    .bind(appUserId, billingPeriod, plan, now.toISOString())
    .run();
}

export async function incrementCloudUnits(
  env: QuotaStoreEnv,
  appUserId: string,
  billingPeriod: string,
  _requestId: string,
  limit: number
): Promise<boolean> {
  if (!hasQuotaD1(env)) {
    return true;
  }

  const row = await env.DB.prepare(
    `UPDATE monthly_usage
     SET used_units = used_units + 1, updated_at = ?
     WHERE app_user_id = ? AND year_month = ? AND used_units < ?
     RETURNING used_units`
  )
    .bind(new Date().toISOString(), appUserId, billingPeriod, limit)
    .first<{ used_units: number }>();

  return Boolean(row);
}

export async function getRemainingUnits(
  env: QuotaStoreEnv,
  appUserId: string,
  billingPeriod: string,
  limit: number
): Promise<number> {
  const usage = await getMonthlyUsage(env, appUserId, billingPeriod);
  return Math.max(0, limit - (usage?.usedUnits ?? 0));
}

export async function checkRequestIdExists(env: QuotaStoreEnv, requestId: string): Promise<boolean> {
  return Boolean(await getCloudUnitRequestLog(env, requestId));
}

export async function getCloudUnitRequestLog(
  env: QuotaStoreEnv,
  requestId: string
): Promise<CloudUnitRequestLogRow | null> {
  if (!hasQuotaD1(env)) {
    return null;
  }

  const row = await env.DB.prepare(
    "SELECT status, remaining_quota, cloud_units_used, plan, usage_date FROM cloud_request_logs WHERE request_id = ?"
  )
    .bind(requestId)
    .first<CloudRequestLogRow>();

  if (!row) {
    return null;
  }

  return {
    status: row.status,
    remainingQuota: row.remaining_quota,
    cloudUnitsUsed: row.cloud_units_used ?? 0,
    plan: row.plan,
    usageDate: row.usage_date
  };
}

export async function recordCloudUnitRequest(
  env: QuotaStoreEnv,
  input: CloudUnitRequestLogInput
): Promise<void> {
  if (!hasQuotaD1(env)) {
    return;
  }

  const now = new Date();
  await upsertAppUser(env.DB, input.appUserId, input.plan, now);
  // Reservation rows are written here before the provider call. d1Store.logCloudRequest
  // later updates the same request_id with success/error details, so this write order
  // is intentional for idempotency and refund safety.
  await env.DB.prepare(
    `INSERT INTO cloud_request_logs
       (request_id, app_user_id, usage_date, feature_type, plan, provider, model,
        status, remaining_quota, scene_json_size, preference_json_size,
        image_upload_enabled, locale, target_platform, created_at,
        cost_usd, cloud_units_used, unit_type)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(request_id) DO NOTHING`
  )
    .bind(
      input.requestId,
      input.appUserId,
      usageDateForLog(input.billingPeriod),
      "cloud_enhancement",
      input.plan,
      input.provider,
      input.model,
      input.status,
      input.remainingUnits,
      byteLength(input.sceneJson ?? ""),
      byteLength(input.userPreferenceJson ?? ""),
      input.imageUploadEnabled ? 1 : 0,
      input.locale ?? "unknown",
      input.targetPlatform ?? "general",
      now.toISOString(),
      null,
      input.cloudUnitsUsed,
      "cloud_enhancement"
    )
    .run();
}

export async function commitCloudUnitRequest(env: QuotaStoreEnv, requestId: string): Promise<void> {
  if (!hasQuotaD1(env)) {
    return;
  }

  await env.DB.prepare(
    "UPDATE cloud_request_logs SET status = ? WHERE request_id = ? AND status = ?"
  )
    .bind("accepted", requestId, "reserved")
    .run();
}

export async function refundCloudUnitRequest(
  env: QuotaStoreEnv,
  requestId: string,
  status: "api_error" | "timeout" | "provider_error",
  errorCode: string | null
): Promise<void> {
  if (!hasQuotaD1(env)) {
    return;
  }

  const existing = await getCloudUnitRequestLog(env, requestId);
  if (!existing || existing.status !== "reserved" || existing.cloudUnitsUsed <= 0) {
    return;
  }

  const billingPeriod = billingPeriodFromLog(existing.plan, existing.usageDate);
  const refundedRemainingUnits = existing.remainingQuota + existing.cloudUnitsUsed;
  await env.DB.batch([
    env.DB.prepare(
      `UPDATE monthly_usage
       SET
         used_units = CASE WHEN used_units >= ? THEN used_units - ? ELSE 0 END,
         updated_at = ?
       WHERE app_user_id = (
         SELECT app_user_id FROM cloud_request_logs WHERE request_id = ?
       )
       AND year_month = ?`
    ).bind(
      existing.cloudUnitsUsed,
      existing.cloudUnitsUsed,
      new Date().toISOString(),
      requestId,
      billingPeriod
    ),
    env.DB.prepare(
      `UPDATE cloud_request_logs
       SET status = ?, remaining_quota = ?, cloud_units_used = 0, error_code = ?
       WHERE request_id = ?`
    ).bind(status, refundedRemainingUnits, errorCode, requestId)
  ]);
}

function mapMonthlyUsageRow(row: MonthlyUsageRow): MonthlyUsageRecord {
  return {
    appUserId: row.app_user_id,
    yearMonth: row.year_month,
    plan: row.plan,
    usedUnits: row.used_units,
    updatedAt: row.updated_at
  };
}

async function upsertAppUser(db: D1Database, appUserId: string, plan: Plan, now: Date): Promise<void> {
  const timestamp = now.toISOString();
  await db
    .prepare(
      `INSERT INTO app_users (app_user_id, current_plan, first_seen_at, last_seen_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(app_user_id)
       DO UPDATE SET current_plan = excluded.current_plan, last_seen_at = excluded.last_seen_at`
    )
    .bind(appUserId, plan, timestamp, timestamp)
    .run();
}

function usageDateForLog(billingPeriod: string): string {
  if (billingPeriod === "LIFETIME") {
    return "1970-01-01";
  }

  if (/^\d{4}-\d{2}$/.test(billingPeriod)) {
    return `${billingPeriod}-01`;
  }

  return billingPeriod;
}

function billingPeriodFromLog(plan: Plan, usageDate: string | null): string {
  if (plan === "free" || usageDate === "1970-01-01") {
    return "LIFETIME";
  }

  if (plan === "beta") {
    return usageDate ?? new Date().toISOString().slice(0, 10);
  }

  return (usageDate ?? new Date().toISOString()).slice(0, 7);
}

function byteLength(value: string): number {
  return new TextEncoder().encode(value).byteLength;
}
