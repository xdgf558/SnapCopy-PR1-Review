import { handleOptions } from "./lib/cors";
import { errorResponse, jsonResponse } from "./lib/response";
import { handleAdminPage } from "./routes/adminPage";
import { handleCloudEnhanceCaption } from "./routes/cloudEnhanceCaption";
import { handleCloudEnhanceVision } from "./routes/cloudEnhanceVision";
import {
  handleContributionConsent,
  handleContributionSample,
  handleSceneRecognitionRecord,
  handleUserFeedbackRecord
} from "./routes/contributions";
import { handleOptimizationRun } from "./routes/optimization";
import {
  handleTrainingDatasetVersionCreate,
  handleTrainingExport,
  handleTrainingDashboardSummary,
  handleTrainingReadinessAlerts,
  handleTrainingReadinessAlertAck,
  handleTrainingReadinessRun,
  handleTrainingSampleList,
  handleTrainingSettingsUpdate,
  handleTrainingReviewSample,
  handleTrainingReviewSamplesBulk
} from "./routes/training";
import { handleUsageStatus } from "./routes/usageStatus";
import { runContributionOptimization } from "./lib/contributionOptimizer";
import { cloudEnhancementUnavailableResponse, isCloudEnhancementEnabled } from "./lib/featureFlags";
import { runTrainingReadinessCheck } from "./lib/trainingPipeline";
import type { Plan } from "./types/api";

type Env = {
  CLOUD_ENHANCEMENT_ENABLED?: string;
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
  VISION_PROVIDER?: string;
  GLM_API_KEY?: string;
  GLM_MODEL?: string;
  GLM_BASE_URL?: string;
  PPQ_API_KEY?: string;
  PPQ_MODEL?: string;
  PPQ_BASE_URL?: string;
  DAILY_GLOBAL_COST_LIMIT_USD?: string;
  MONTHLY_GLOBAL_COST_LIMIT_USD?: string;
  PLUS_MONTHLY_COST_ALERT_USD?: string;
  PRO_MONTHLY_COST_ALERT_USD?: string;
  OPTIMIZATION_ADMIN_TOKEN?: string;
  OPTIMIZATION_MIN_CAPTION_SAMPLES?: string;
  OPTIMIZATION_COOLDOWN_HOURS?: string;
  OPTIMIZATION_MAX_BUCKETS_PER_RUN?: string;
  TRAINING_READY_SCENE_THRESHOLD?: string;
  TRAINING_EXPORT_MAX_ROWS?: string;
  ALLOW_CLIENT_PLAN_OVERRIDE?: string;
  DB?: D1Database;
  TRAINING_IMAGES?: R2Bucket;
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return handleOptions();
    }

    const url = new URL(request.url);

    if (url.pathname === "/" && request.method === "GET") {
      return jsonResponse({
        name: "snapcopy-cloud-api",
        status: "ok",
        provider: env.DEFAULT_PROVIDER ?? "mock"
      });
    }

    if ((url.pathname === "/admin" || url.pathname === "/admin/") && (request.method === "GET" || request.method === "HEAD")) {
      return handleAdminPage();
    }

    if (url.pathname.startsWith("/api/cloud-enhance/") && !isCloudEnhancementEnabled(env)) {
      return cloudEnhancementUnavailableResponse();
    }

    if (url.pathname === "/api/cloud-enhance/caption" && request.method === "POST") {
      return handleCloudEnhanceCaption(request, env);
    }

    if (url.pathname === "/api/cloud-enhance/vision" && request.method === "POST") {
      return handleCloudEnhanceVision(request, env);
    }

    if (url.pathname === "/api/usage/status" && request.method === "GET") {
      return handleUsageStatus(request, env);
    }

    if (url.pathname === "/api/contributions/consent" && request.method === "POST") {
      return handleContributionConsent(request, env);
    }

    if (url.pathname === "/api/contributions/sample" && request.method === "POST") {
      return handleContributionSample(request, env);
    }

    if (url.pathname === "/api/contributions/scene-recognition" && request.method === "POST") {
      return handleSceneRecognitionRecord(request, env);
    }

    if (url.pathname === "/api/contributions/feedback" && request.method === "POST") {
      return handleUserFeedbackRecord(request, env);
    }

    if (url.pathname === "/api/admin/optimization/run" && request.method === "POST") {
      return handleOptimizationRun(request, env);
    }

    if (url.pathname === "/api/admin/training/export" && request.method === "GET") {
      return handleTrainingExport(request, env);
    }

    if (url.pathname === "/api/admin/training/summary" && request.method === "GET") {
      return handleTrainingDashboardSummary(request, env);
    }

    if (url.pathname === "/api/admin/training/settings" && request.method === "POST") {
      return handleTrainingSettingsUpdate(request, env);
    }

    if (url.pathname === "/api/admin/training/samples" && request.method === "GET") {
      return handleTrainingSampleList(request, env);
    }

    if (url.pathname === "/api/admin/training/readiness/run" && request.method === "POST") {
      return handleTrainingReadinessRun(request, env);
    }

    if (url.pathname === "/api/admin/training/readiness/alerts" && request.method === "GET") {
      return handleTrainingReadinessAlerts(request, env);
    }

    if (url.pathname === "/api/admin/training/readiness/ack" && request.method === "POST") {
      return handleTrainingReadinessAlertAck(request, env);
    }

    if (url.pathname === "/api/admin/training/review-sample" && request.method === "POST") {
      return handleTrainingReviewSample(request, env);
    }

    if (url.pathname === "/api/admin/training/review-samples" && request.method === "POST") {
      return handleTrainingReviewSamplesBulk(request, env);
    }

    if (url.pathname === "/api/admin/training/dataset-version" && request.method === "POST") {
      return handleTrainingDatasetVersionCreate(request, env);
    }

    return errorResponse("not_found", "Route not found.", 404);
  },

  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    await runContributionOptimization(env);
    await runTrainingReadinessCheck(env);
  }
};
