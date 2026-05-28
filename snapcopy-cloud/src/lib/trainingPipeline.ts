import { hasD1, type D1Env } from "./d1Store";
import type { ContributionReviewStatus, TrainingDatasetVersionRequest } from "../types/api";

export type TrainingPipelineEnv = D1Env & {
  TRAINING_READY_SCENE_THRESHOLD?: string;
  TRAINING_EXPORT_MAX_ROWS?: string;
  CLOUD_ENHANCEMENT_ENABLED?: string;
};

export type TrainingExportOptions = {
  kind?: "photo" | "caption";
  status?: ContributionReviewStatus;
  scene?: string;
  limit?: number;
};

export type TrainingReadinessResult = {
  storageMode: "d1" | "disabled";
  threshold: number;
  checkedBuckets: number;
  createdAlerts: number;
};

export type ReviewSampleInput = {
  sampleId: string;
  reviewStatus: ContributionReviewStatus;
  reviewReason?: string | null;
  reviewedBy?: string | null;
  datasetVersion?: string | null;
};

export type BulkReviewSampleInput = {
  sampleIds: string[];
  reviewStatus: ContributionReviewStatus;
  reviewReason?: string | null;
  reviewedBy?: string | null;
  datasetVersion?: string | null;
};

type CountRow = {
  kind: "photo" | "caption";
  scene: string;
  eligible_count: number;
};

type ExistingAlertRow = {
  alert_id: string;
};

type StatusCountRow = {
  review_status: string;
  sample_count: number;
};

type SceneCountRow = {
  kind: string;
  scene: string;
  approved_count: number;
};

type OpenAlertCountRow = {
  open_alert_count: number;
};

type SettingRow = {
  setting_value: string;
};

export type TrainingSampleExportRow = {
  sample_id: string;
  kind: string;
  source: string;
  review_status: string;
  app_user_id: string;
  consent_id: string;
  locale: string;
  target_platform: string | null;
  scene: string | null;
  scene_confidence: number | null;
  scene_tags_json: string;
  scene_json: string | null;
  caption_text: string | null;
  caption_was_edited: number;
  r2_object_key: string | null;
  image_mime_type: string | null;
  image_width: number | null;
  image_height: number | null;
  image_byte_size: number | null;
  image_sha256: string | null;
  privacy_redaction_status: string;
  original_photo_retention: string;
  used_in_dataset_version: string | null;
  created_at: string;
  received_at: string;
};

export type TrainingSampleListOptions = {
  kind?: "photo" | "caption";
  status?: ContributionReviewStatus;
  scene?: string;
  limit?: number;
};

export type TrainingSampleListRow = Pick<
  TrainingSampleExportRow,
  | "sample_id"
  | "kind"
  | "source"
  | "review_status"
  | "locale"
  | "target_platform"
  | "scene"
  | "scene_confidence"
  | "caption_text"
  | "caption_was_edited"
  | "r2_object_key"
  | "image_mime_type"
  | "image_width"
  | "image_height"
  | "privacy_redaction_status"
  | "created_at"
  | "received_at"
>;

export type TrainingAdminSettings = {
  trainingReadySceneThreshold: number;
  cloudEnhancementEnabled: boolean;
  source: "d1" | "env" | "default";
};

export async function exportTrainingSamples(
  env: TrainingPipelineEnv,
  options: TrainingExportOptions
): Promise<TrainingSampleExportRow[]> {
  const maxRows = numberFromEnv(env.TRAINING_EXPORT_MAX_ROWS, 5000);
  if (!hasD1(env)) {
    return [];
  }

  const limit = Math.max(1, Math.min(options.limit ?? maxRows, maxRows));
  const where: string[] = ["review_status = ?"];
  const bindings: Array<string | number> = [options.status ?? "approved"];

  if (options.kind) {
    where.push("kind = ?");
    bindings.push(options.kind);
  }

  if (options.scene) {
    where.push("COALESCE(scene, 'unknown') = ?");
    bindings.push(options.scene);
  }

  bindings.push(limit);

  const result = await env.DB.prepare(
    `SELECT
       sample_id, kind, source, review_status, app_user_id, consent_id,
       locale, target_platform, scene, scene_confidence, scene_tags_json,
       scene_json, caption_text, caption_was_edited, r2_object_key,
       image_mime_type, image_width, image_height, image_byte_size, image_sha256,
       privacy_redaction_status, original_photo_retention, used_in_dataset_version,
       created_at, received_at
     FROM training_contribution_samples
     WHERE ${where.join(" AND ")}
     ORDER BY received_at DESC
     LIMIT ?`
  )
    .bind(...bindings)
    .all<TrainingSampleExportRow>();

  return result.results ?? [];
}

export function trainingSamplesToCSV(rows: TrainingSampleExportRow[]): string {
  const headers: Array<keyof TrainingSampleExportRow> = [
    "sample_id",
    "kind",
    "source",
    "review_status",
    "locale",
    "target_platform",
    "scene",
    "scene_confidence",
    "scene_tags_json",
    "caption_text",
    "caption_was_edited",
    "r2_object_key",
    "image_mime_type",
    "image_width",
    "image_height",
    "image_byte_size",
    "image_sha256",
    "privacy_redaction_status",
    "original_photo_retention",
    "used_in_dataset_version",
    "created_at",
    "received_at"
  ];

  const lines = [headers.join(",")];
  for (const row of rows) {
    lines.push(headers.map((header) => csvEscape(row[header])).join(","));
  }

  return `${lines.join("\n")}\n`;
}

export async function runTrainingReadinessCheck(
  env: TrainingPipelineEnv,
  now = new Date()
): Promise<TrainingReadinessResult> {
  const threshold = await resolveTrainingReadySceneThreshold(env);
  if (!hasD1(env)) {
    return {
      storageMode: "disabled",
      threshold,
      checkedBuckets: 0,
      createdAlerts: 0
    };
  }

  const buckets = await env.DB.prepare(
    `SELECT
       kind,
       COALESCE(scene, 'unknown') AS scene,
       COUNT(*) AS eligible_count
     FROM training_contribution_samples
     WHERE review_status = 'approved'
       AND kind IN ('photo', 'caption')
     GROUP BY kind, COALESCE(scene, 'unknown')
     HAVING COUNT(*) >= ?
     ORDER BY eligible_count DESC`
  )
    .bind(threshold)
    .all<CountRow>();

  let createdAlerts = 0;
  for (const bucket of buckets.results ?? []) {
    const existing = await env.DB.prepare(
      `SELECT alert_id
       FROM training_readiness_alerts
       WHERE status = 'open'
         AND kind = ?
         AND scene = ?
         AND threshold = ?
       LIMIT 1`
    )
      .bind(bucket.kind, bucket.scene, threshold)
      .first<ExistingAlertRow>();

    if (existing) {
      continue;
    }

    const datasetTarget = nextDatasetTarget(now);
    const unit = bucket.kind === "photo" ? "张可用图片" : "条可用文案";
    const message = `${bucket.scene} 类新增 ${bucket.eligible_count} ${unit}样本，可以人工审核并准备 ${datasetTarget} 训练。`;
    await env.DB.prepare(
      `INSERT INTO training_readiness_alerts (
         alert_id, alert_type, kind, scene, eligible_count, threshold,
         dataset_target, status, message, created_at
       )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        crypto.randomUUID(),
        "scene_sample_threshold",
        bucket.kind,
        bucket.scene,
        bucket.eligible_count,
        threshold,
        datasetTarget,
        "open",
        message,
        now.toISOString()
      )
      .run();
    createdAlerts += 1;
  }

  return {
    storageMode: "d1",
    threshold,
    checkedBuckets: buckets.results?.length ?? 0,
    createdAlerts
  };
}

export async function listTrainingReadinessAlerts(env: TrainingPipelineEnv): Promise<unknown[]> {
  if (!hasD1(env)) {
    return [];
  }

  const result = await env.DB.prepare(
    `SELECT alert_id, alert_type, kind, scene, eligible_count, threshold,
            dataset_target, status, message, created_at, acknowledged_at
     FROM training_readiness_alerts
     ORDER BY created_at DESC
     LIMIT 100`
  ).all();

  return result.results ?? [];
}

export async function getTrainingDashboardSummary(env: TrainingPipelineEnv): Promise<unknown> {
  const settings = await getTrainingAdminSettings(env);
  if (!hasD1(env)) {
    return {
      storageMode: "disabled",
      statusCounts: [],
      approvedSceneCounts: [],
      openAlertCount: 0,
      settings
    };
  }

  const statusCounts = await env.DB.prepare(
    `SELECT review_status, COUNT(*) AS sample_count
     FROM training_contribution_samples
     GROUP BY review_status
     ORDER BY sample_count DESC`
  ).all<StatusCountRow>();

  const approvedSceneCounts = await env.DB.prepare(
    `SELECT kind, COALESCE(scene, 'unknown') AS scene, COUNT(*) AS approved_count
     FROM training_contribution_samples
     WHERE review_status = 'approved'
     GROUP BY kind, COALESCE(scene, 'unknown')
     ORDER BY approved_count DESC
     LIMIT 30`
  ).all<SceneCountRow>();

  const openAlert = await env.DB.prepare(
    `SELECT COUNT(*) AS open_alert_count
     FROM training_readiness_alerts
     WHERE status = 'open'`
  ).first<OpenAlertCountRow>();

  return {
    storageMode: "d1",
    statusCounts: statusCounts.results ?? [],
    approvedSceneCounts: approvedSceneCounts.results ?? [],
    openAlertCount: openAlert?.open_alert_count ?? 0,
    settings
  };
}

export async function getTrainingAdminSettings(env: TrainingPipelineEnv): Promise<TrainingAdminSettings> {
  const envThreshold = env.TRAINING_READY_SCENE_THRESHOLD;
  const envValue = numberFromEnv(envThreshold, 300);
  const envCloudEnhancementEnabled = stringFlagEnabled(env.CLOUD_ENHANCEMENT_ENABLED, true);
  const fallbackSource = envThreshold ? "env" : "default";
  if (!hasD1(env)) {
    return {
      trainingReadySceneThreshold: envValue,
      cloudEnhancementEnabled: envCloudEnhancementEnabled,
      source: fallbackSource
    };
  }

  const rows = await env.DB.prepare(
    `SELECT setting_key, setting_value
     FROM training_admin_settings
     WHERE setting_key IN (?, ?)`
  )
    .bind("training_ready_scene_threshold", "cloud_enhancement_enabled")
    .all<SettingRow & { setting_key: string }>();

  const settings = Object.fromEntries((rows.results ?? []).map(row => [row.setting_key, row.setting_value]));
  const thresholdValue = settings.training_ready_scene_threshold;
  const cloudEnhancementValue = settings.cloud_enhancement_enabled;
  const hasD1Setting = Boolean(thresholdValue || cloudEnhancementValue);

  return {
    trainingReadySceneThreshold: numberFromEnv(thresholdValue, envValue),
    cloudEnhancementEnabled: stringFlagEnabled(cloudEnhancementValue, envCloudEnhancementEnabled),
    source: hasD1Setting ? "d1" : fallbackSource
  };
}

export async function updateTrainingAdminSettings(
  env: TrainingPipelineEnv,
  settings: Partial<Pick<TrainingAdminSettings, "trainingReadySceneThreshold" | "cloudEnhancementEnabled">>
): Promise<TrainingAdminSettings & { storageMode: "d1" | "disabled" }> {
  const current = await getTrainingAdminSettings(env);
  const threshold = clampThreshold(settings.trainingReadySceneThreshold ?? current.trainingReadySceneThreshold);
  const cloudEnhancementEnabled = settings.cloudEnhancementEnabled ?? current.cloudEnhancementEnabled;
  if (!hasD1(env)) {
    return {
      trainingReadySceneThreshold: threshold,
      cloudEnhancementEnabled,
      source: "default",
      storageMode: "disabled"
    };
  }

  const now = new Date().toISOString();
  await env.DB.batch([
    upsertAdminSettingStatement(env.DB, "training_ready_scene_threshold", String(threshold), now),
    upsertAdminSettingStatement(env.DB, "cloud_enhancement_enabled", String(cloudEnhancementEnabled), now)
  ]);

  return {
    trainingReadySceneThreshold: threshold,
    cloudEnhancementEnabled,
    source: "d1",
    storageMode: "d1"
  };
}

export async function listTrainingSamples(
  env: TrainingPipelineEnv,
  options: TrainingSampleListOptions
): Promise<TrainingSampleListRow[]> {
  if (!hasD1(env)) {
    return [];
  }

  const limit = Math.max(1, Math.min(options.limit ?? 50, 100));
  const where: string[] = [];
  const bindings: Array<string | number> = [];

  if (options.status) {
    where.push("review_status = ?");
    bindings.push(options.status);
  }

  if (options.kind) {
    where.push("kind = ?");
    bindings.push(options.kind);
  }

  if (options.scene) {
    where.push("COALESCE(scene, 'unknown') = ?");
    bindings.push(options.scene);
  }

  bindings.push(limit);

  const whereClause = where.length > 0 ? `WHERE ${where.join(" AND ")}` : "";
  const result = await env.DB.prepare(
    `SELECT
       sample_id, kind, source, review_status, locale, target_platform,
       scene, scene_confidence, caption_text, caption_was_edited, r2_object_key,
       image_mime_type, image_width, image_height, privacy_redaction_status,
       created_at, received_at
     FROM training_contribution_samples
     ${whereClause}
     ORDER BY received_at DESC
     LIMIT ?`
  )
    .bind(...bindings)
    .all<TrainingSampleListRow>();

  return result.results ?? [];
}

export async function acknowledgeTrainingReadinessAlert(
  env: TrainingPipelineEnv,
  alertId: string
): Promise<"d1" | "disabled"> {
  if (!hasD1(env)) {
    return "disabled";
  }

  await env.DB.prepare(
    `UPDATE training_readiness_alerts
     SET status = 'acknowledged',
         acknowledged_at = ?
     WHERE alert_id = ?`
  )
    .bind(new Date().toISOString(), alertId)
    .run();

  return "d1";
}

export async function updateSampleReviewStatus(
  env: TrainingPipelineEnv,
  input: ReviewSampleInput
): Promise<"d1" | "disabled"> {
  if (!hasD1(env)) {
    return "disabled";
  }

  const reviewedAt = new Date().toISOString();
  await env.DB.prepare(
    `UPDATE training_contribution_samples
     SET review_status = ?,
         review_reason = ?,
         reviewed_by = ?,
         reviewed_at = ?,
         used_in_dataset_version = CASE WHEN ? IS NOT NULL THEN ? ELSE used_in_dataset_version END
     WHERE sample_id = ?`
  )
    .bind(
      input.reviewStatus,
      input.reviewReason ?? null,
      input.reviewedBy ?? null,
      reviewedAt,
      input.datasetVersion ?? null,
      input.datasetVersion ?? null,
      input.sampleId
    )
    .run();

  return "d1";
}

export async function updateSampleReviewStatuses(
  env: TrainingPipelineEnv,
  input: BulkReviewSampleInput
): Promise<{ storageMode: "d1" | "disabled"; updatedCount: number }> {
  if (!hasD1(env)) {
    return { storageMode: "disabled", updatedCount: 0 };
  }

  const reviewedAt = new Date().toISOString();
  let updatedCount = 0;

  for (const sampleId of input.sampleIds) {
    const result = await env.DB.prepare(
      `UPDATE training_contribution_samples
       SET review_status = ?,
           review_reason = ?,
           reviewed_by = ?,
           reviewed_at = ?,
           used_in_dataset_version = CASE WHEN ? IS NOT NULL THEN ? ELSE used_in_dataset_version END
       WHERE sample_id = ?`
    )
      .bind(
        input.reviewStatus,
        input.reviewReason ?? null,
        input.reviewedBy ?? null,
        reviewedAt,
        input.datasetVersion ?? null,
        input.datasetVersion ?? null,
        sampleId
      )
      .run();

    updatedCount += result.meta.changes ?? 0;
  }

  return { storageMode: "d1", updatedCount };
}

export async function upsertTrainingDatasetVersion(
  env: TrainingPipelineEnv,
  input: TrainingDatasetVersionRequest
): Promise<"d1" | "disabled"> {
  if (!hasD1(env)) {
    return "disabled";
  }

  await env.DB.prepare(
    `INSERT INTO training_dataset_versions (
       dataset_version, dataset_type, status, source_filter_json, sample_count,
       scene_counts_json, notes, created_at, exported_at
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(dataset_version)
     DO UPDATE SET
       dataset_type = excluded.dataset_type,
       status = excluded.status,
       source_filter_json = excluded.source_filter_json,
       sample_count = excluded.sample_count,
       scene_counts_json = excluded.scene_counts_json,
       notes = excluded.notes,
       exported_at = excluded.exported_at`
  )
    .bind(
      input.datasetVersion,
      input.datasetType,
      input.status ?? "draft",
      JSON.stringify(input.sourceFilter ?? {}),
      input.sampleCount ?? 0,
      JSON.stringify(input.sceneCounts ?? {}),
      input.notes ?? null,
      new Date().toISOString(),
      input.exportedAt ?? null
    )
    .run();

  return "d1";
}

function csvEscape(value: unknown): string {
  if (value === null || value === undefined) {
    return "";
  }

  const text = String(value);
  if (!/[",\n\r]/.test(text)) {
    return text;
  }

  return `"${text.replace(/"/g, '""')}"`;
}

function numberFromEnv(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function stringFlagEnabled(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }

  return value.trim().toLowerCase() !== "false";
}

async function resolveTrainingReadySceneThreshold(env: TrainingPipelineEnv): Promise<number> {
  const settings = await getTrainingAdminSettings(env);
  return settings.trainingReadySceneThreshold;
}

function clampThreshold(value: number): number {
  if (!Number.isFinite(value)) {
    return 300;
  }

  return Math.max(10, Math.min(Math.round(value), 10000));
}

function upsertAdminSettingStatement(db: D1Database, key: string, value: string, updatedAt: string): D1PreparedStatement {
  return db.prepare(
    `INSERT INTO training_admin_settings (setting_key, setting_value, updated_at)
     VALUES (?, ?, ?)
     ON CONFLICT(setting_key)
     DO UPDATE SET
       setting_value = excluded.setting_value,
       updated_at = excluded.updated_at`
  ).bind(key, value, updatedAt);
}

function nextDatasetTarget(now: Date): string {
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `v${year}.${month}`;
}
