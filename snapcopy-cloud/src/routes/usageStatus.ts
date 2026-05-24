import { dailyLimitForPlan, getUsage } from "../lib/quota";
import { jsonResponse, errorResponse } from "../lib/response";
import { resolveEffectivePlan } from "../lib/validators";
import type { Plan, UsageStatusResponse } from "../types/api";

type Env = {
  DEFAULT_PLAN?: Plan;
};

export async function handleUsageStatus(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const appUserId = url.searchParams.get("appUserId");
  if (!appUserId) {
    return errorResponse("missing_app_user_id", "appUserId query parameter is required.", 400);
  }

  const plan = resolveEffectivePlan(url.searchParams.get("plan"), env.DEFAULT_PLAN ?? "beta");
  const usage = getUsage(appUserId);
  const dailyLimit = dailyLimitForPlan(plan);
  const response: UsageStatusResponse = {
    plan,
    dailyLimit,
    usedToday: usage.usedToday,
    remainingQuota: Math.max(0, dailyLimit - usage.usedToday)
  };

  return jsonResponse(response);
}
