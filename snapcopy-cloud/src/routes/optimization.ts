import { runContributionOptimization } from "../lib/contributionOptimizer";
import { errorResponse, jsonResponse } from "../lib/response";

type Env = {
  DB?: D1Database;
  OPTIMIZATION_ADMIN_TOKEN?: string;
  OPTIMIZATION_MIN_CAPTION_SAMPLES?: string;
  OPTIMIZATION_COOLDOWN_HOURS?: string;
  OPTIMIZATION_MAX_BUCKETS_PER_RUN?: string;
};

export async function handleOptimizationRun(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get("authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!env.OPTIMIZATION_ADMIN_TOKEN || token !== env.OPTIMIZATION_ADMIN_TOKEN) {
    return errorResponse("unauthorized", "Optimization admin token is required.", 401);
  }

  const result = await runContributionOptimization(env);
  return jsonResponse({
    ok: true,
    result
  });
}
