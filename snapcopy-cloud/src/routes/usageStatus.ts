import { jsonResponse, errorResponse } from "../lib/response";
import { resolveEffectivePlan } from "../lib/validators";
import { getUsageStatusFromStore } from "../lib/d1Store";
import type { Plan, UsageStatusResponse } from "../types/api";

type Env = {
  DEFAULT_PLAN?: Plan;
  DB?: D1Database;
};

export async function handleUsageStatus(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const appUserId = url.searchParams.get("appUserId");
  if (!appUserId) {
    return errorResponse("missing_app_user_id", "appUserId query parameter is required.", 400);
  }

  // Plan display also follows the server-side default until StoreKit validation is connected.
  const plan = resolveEffectivePlan(undefined, env.DEFAULT_PLAN ?? "beta");
  const response: UsageStatusResponse = await getUsageStatusFromStore(env, appUserId, plan);

  return jsonResponse(response);
}
