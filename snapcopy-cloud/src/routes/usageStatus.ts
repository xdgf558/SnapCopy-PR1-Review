import { jsonResponse, errorResponse } from "../lib/response";
import { resolveEffectivePlan } from "../lib/validators";
import { getUsageStatusFromStore } from "../lib/d1Store";
import type { Plan, UsageStatusResponse } from "../types/api";

type Env = {
  DEFAULT_PLAN?: Plan;
  ALLOW_CLIENT_PLAN_OVERRIDE?: string;
  DB?: D1Database;
};

export async function handleUsageStatus(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const appUserId = url.searchParams.get("appUserId");
  if (!appUserId) {
    return errorResponse("missing_app_user_id", "appUserId query parameter is required.", 400);
  }

  const requestedPlan = url.searchParams.get("plan");
  const plan = resolveEffectivePlan(
    env.ALLOW_CLIENT_PLAN_OVERRIDE === "true" ? requestedPlan : undefined,
    env.DEFAULT_PLAN ?? "beta"
  );
  const response: UsageStatusResponse = await getUsageStatusFromStore(
    env,
    appUserId,
    plan,
    url.searchParams.get("clientAppVersion") ?? undefined,
    url.searchParams.get("clientBuild") ?? undefined
  );

  return jsonResponse(response);
}
