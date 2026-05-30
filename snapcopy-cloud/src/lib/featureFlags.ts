import { jsonResponse } from "./response";

export type CloudFeatureFlagEnv = {
  CLOUD_ENHANCEMENT_ENABLED?: string;
  DB?: D1Database;
};

let costCircuitBreakerDisabled = false;

export function isCloudEnhancementEnabled(env: CloudFeatureFlagEnv): boolean {
  return (env.CLOUD_ENHANCEMENT_ENABLED ?? "true").toLowerCase() !== "false";
}

export async function isCloudEnhancementAvailable(env: CloudFeatureFlagEnv): Promise<boolean> {
  if (!isCloudEnhancementEnabled(env) || costCircuitBreakerDisabled) {
    return false;
  }

  if (!env.DB) {
    return true;
  }

  try {
    const row = await env.DB.prepare(
      `SELECT setting_value
       FROM training_admin_settings
       WHERE setting_key = ?`
    )
      .bind("cloud_enhancement_enabled")
      .first<{ setting_value: string }>();

    return (row?.setting_value ?? "true").trim().toLowerCase() !== "false";
  } catch {
    return true;
  }
}

export async function disableCloudEnhancementForCost(env: CloudFeatureFlagEnv, reason: string): Promise<void> {
  costCircuitBreakerDisabled = true;
  if (!env.DB) {
    return;
  }

  const now = new Date().toISOString();
  try {
    await env.DB.batch([
      upsertAdminSettingStatement(env.DB, "cloud_enhancement_enabled", "false", now),
      upsertAdminSettingStatement(env.DB, "cloud_enhancement_disabled_reason", reason, now)
    ]);
  } catch {
    // In-memory breaker is enough for the current Worker lifecycle.
  }
}

export function cloudEnhancementUnavailableResponse(): Response {
  return jsonResponse(
    {
      error: "cloud_enhancement_unavailable",
      message: "云端增强暂时繁忙，请使用本地生成"
    },
    { status: 503 }
  );
}

function upsertAdminSettingStatement(
  db: D1Database,
  key: string,
  value: string,
  updatedAt: string
): D1PreparedStatement {
  return db.prepare(
    `INSERT INTO training_admin_settings (setting_key, setting_value, updated_at)
     VALUES (?, ?, ?)
     ON CONFLICT(setting_key)
     DO UPDATE SET setting_value = excluded.setting_value, updated_at = excluded.updated_at`
  ).bind(key, value, updatedAt);
}
