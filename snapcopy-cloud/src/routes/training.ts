import { corsHeaders } from "../lib/cors";
import { errorResponse, jsonResponse } from "../lib/response";
import {
  exportTrainingSamples,
  getTrainingDashboardSummary,
  listTrainingSamples,
  listTrainingReadinessAlerts,
  acknowledgeTrainingReadinessAlert,
  runTrainingReadinessCheck,
  trainingSamplesToCSV,
  updateSampleReviewStatus,
  updateSampleReviewStatuses,
  updateTrainingAdminSettings,
  upsertTrainingDatasetVersion,
  type BulkReviewSampleInput,
  type ReviewSampleInput
} from "../lib/trainingPipeline";
import {
  parseJsonBody,
  validateTrainingDatasetVersionRequest,
  ValidationError
} from "../lib/validators";
import type { ContributionReviewStatus, TrainingDatasetVersionRequest } from "../types/api";

type Env = {
  DB?: D1Database;
  OPTIMIZATION_ADMIN_TOKEN?: string;
  TRAINING_READY_SCENE_THRESHOLD?: string;
  TRAINING_EXPORT_MAX_ROWS?: string;
  CLOUD_ENHANCEMENT_ENABLED?: string;
};

const validReviewStatuses = new Set(["pending", "approved", "rejected", "used_in_training"]);

export async function handleTrainingExport(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  const url = new URL(request.url);
  const format = url.searchParams.get("format") ?? "json";
  const kind = optionalKind(url.searchParams.get("kind"));
  const status = optionalReviewStatus(url.searchParams.get("status")) ?? "approved";
  const scene = url.searchParams.get("scene") ?? undefined;
  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? Number(limitParam) : undefined;
  const rows = await exportTrainingSamples(env, { kind, status, scene, limit });

  if (format === "csv") {
    const csv = trainingSamplesToCSV(rows);
    return new Response(csv, {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="snapcopy-training-export-${status}.csv"`,
        ...corsHeaders()
      }
    });
  }

  return jsonResponse({
    ok: true,
    count: rows.length,
    status,
    kind: kind ?? "all",
    scene: scene ?? "all",
    rows
  });
}

export async function handleTrainingReadinessRun(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  const result = await runTrainingReadinessCheck(env);
  return jsonResponse({
    ok: true,
    result
  });
}

export async function handleTrainingReadinessAlerts(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  const alerts = await listTrainingReadinessAlerts(env);
  return jsonResponse({
    ok: true,
    alerts
  });
}

export async function handleTrainingDashboardSummary(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  const summary = await getTrainingDashboardSummary(env);
  return jsonResponse({
    ok: true,
    summary
  });
}

export async function handleTrainingSettingsUpdate(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  try {
    const input = await parseJsonBody<{ trainingReadySceneThreshold?: number; cloudEnhancementEnabled?: boolean }>(request, 16_000);
    const threshold = input.trainingReadySceneThreshold;
    const hasThreshold = threshold !== undefined;
    const hasCloudToggle = input.cloudEnhancementEnabled !== undefined;

    if (!hasThreshold && !hasCloudToggle) {
      return errorResponse("missing_settings", "At least one setting is required.", 400);
    }

    if (hasThreshold && (
      typeof threshold !== "number" ||
      !Number.isFinite(threshold) ||
      !Number.isInteger(threshold) ||
      threshold < 10 ||
      threshold > 10000
    )) {
      return errorResponse("invalid_threshold", "trainingReadySceneThreshold must be an integer from 10 to 10000.", 400);
    }

    if (hasCloudToggle && typeof input.cloudEnhancementEnabled !== "boolean") {
      return errorResponse("invalid_cloud_toggle", "cloudEnhancementEnabled must be a boolean.", 400);
    }

    const settings = await updateTrainingAdminSettings(env, {
      ...(hasThreshold ? { trainingReadySceneThreshold: threshold } : {}),
      ...(hasCloudToggle ? { cloudEnhancementEnabled: input.cloudEnhancementEnabled } : {})
    });

    return jsonResponse({
      ok: true,
      settings
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Training settings update failed.", 500);
  }
}

export async function handleTrainingSampleList(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  const url = new URL(request.url);
  const kind = optionalKind(url.searchParams.get("kind"));
  const status = optionalReviewStatus(url.searchParams.get("status")) ?? "pending";
  const scene = url.searchParams.get("scene") ?? undefined;
  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? Number(limitParam) : undefined;
  const samples = await listTrainingSamples(env, { kind, status, scene, limit });

  return jsonResponse({
    ok: true,
    count: samples.length,
    status,
    kind: kind ?? "all",
    scene: scene ?? "all",
    samples
  });
}

export async function handleTrainingReadinessAlertAck(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  try {
    const input = await parseJsonBody<{ alertId?: string }>(request, 16_000);
    if (!input.alertId || typeof input.alertId !== "string") {
      return errorResponse("missing_alert_id", "alertId is required.", 400);
    }

    const storageMode = await acknowledgeTrainingReadinessAlert(env, input.alertId);
    return jsonResponse({
      ok: true,
      alertId: input.alertId,
      status: "acknowledged",
      storageMode
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Training alert acknowledgement failed.", 500);
  }
}

export async function handleTrainingReviewSample(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  try {
    const input = await parseJsonBody<ReviewSampleInput>(request, 64_000);
    if (!input.sampleId || typeof input.sampleId !== "string") {
      return errorResponse("missing_sample_id", "sampleId is required.", 400);
    }
    if (!validReviewStatuses.has(input.reviewStatus)) {
      return errorResponse("invalid_review_status", "reviewStatus is invalid.", 400);
    }

    const storageMode = await updateSampleReviewStatus(env, input);
    return jsonResponse({
      ok: true,
      sampleId: input.sampleId,
      reviewStatus: input.reviewStatus,
      storageMode
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Training review update failed.", 500);
  }
}

export async function handleTrainingReviewSamplesBulk(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  try {
    const input = await parseJsonBody<BulkReviewSampleInput>(request, 128_000);
    if (!Array.isArray(input.sampleIds) || input.sampleIds.length === 0) {
      return errorResponse("missing_sample_ids", "sampleIds is required.", 400);
    }
    if (input.sampleIds.length > 100) {
      return errorResponse("too_many_sample_ids", "At most 100 samples can be reviewed at once.", 400);
    }
    if (!input.sampleIds.every(sampleId => typeof sampleId === "string" && sampleId.trim().length > 0)) {
      return errorResponse("invalid_sample_ids", "sampleIds must be non-empty strings.", 400);
    }
    if (!validReviewStatuses.has(input.reviewStatus)) {
      return errorResponse("invalid_review_status", "reviewStatus is invalid.", 400);
    }

    const result = await updateSampleReviewStatuses(env, {
      ...input,
      sampleIds: Array.from(new Set(input.sampleIds.map(sampleId => sampleId.trim())))
    });

    return jsonResponse({
      ok: true,
      requestedCount: input.sampleIds.length,
      updatedCount: result.updatedCount,
      reviewStatus: input.reviewStatus,
      storageMode: result.storageMode
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Training bulk review update failed.", 500);
  }
}

export async function handleTrainingDatasetVersionCreate(request: Request, env: Env): Promise<Response> {
  if (!isAdminAuthorized(request, env)) {
    return errorResponse("unauthorized", "Training admin token is required.", 401);
  }

  try {
    const body = await parseJsonBody<TrainingDatasetVersionRequest>(request, 128_000);
    const input = validateTrainingDatasetVersionRequest(body);
    const storageMode = await upsertTrainingDatasetVersion(env, input);
    return jsonResponse({
      ok: true,
      datasetVersion: input.datasetVersion,
      storageMode
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Training dataset version update failed.", 500);
  }
}

function isAdminAuthorized(request: Request, env: Env): boolean {
  const authHeader = request.headers.get("authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  return Boolean(env.OPTIMIZATION_ADMIN_TOKEN && token === env.OPTIMIZATION_ADMIN_TOKEN);
}

function optionalKind(value: string | null): "photo" | "caption" | undefined {
  return value === "photo" || value === "caption" ? value : undefined;
}

function optionalReviewStatus(value: string | null): ContributionReviewStatus | undefined {
  return validReviewStatuses.has(value ?? "") ? (value as ContributionReviewStatus) : undefined;
}
