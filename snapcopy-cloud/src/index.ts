import { handleOptions } from "./lib/cors";
import { errorResponse, jsonResponse } from "./lib/response";
import { handleCloudEnhanceCaption } from "./routes/cloudEnhanceCaption";
import { handleCloudEnhanceVision } from "./routes/cloudEnhanceVision";
import { handleContributionConsent, handleContributionSample } from "./routes/contributions";
import { handleUsageStatus } from "./routes/usageStatus";
import type { Plan } from "./types/api";

type Env = {
  DEFAULT_PLAN?: Plan;
  DEFAULT_PROVIDER?: string;
  DB?: D1Database;
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

    if (url.pathname === "/api/cloud-enhance/caption" && request.method === "POST") {
      return handleCloudEnhanceCaption(request, env);
    }

    if (url.pathname === "/api/cloud-enhance/vision" && request.method === "POST") {
      return handleCloudEnhanceVision();
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

    return errorResponse("not_found", "Route not found.", 404);
  }
};
