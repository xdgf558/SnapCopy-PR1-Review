import { consumeQuota, canConsumeQuota } from "../lib/quota";
import { jsonResponse, errorResponse } from "../lib/response";
import { makeMockCaptions } from "../lib/mockCaptions";
import { parseJsonBody, resolveEffectivePlan, validateCaptionRequest, ValidationError } from "../lib/validators";
import type { CloudCaptionRequest, CloudCaptionResponse, Plan } from "../types/api";

type Env = {
  DEFAULT_PLAN?: Plan;
  DEFAULT_PROVIDER?: string;
};

export async function handleCloudEnhanceCaption(request: Request, env: Env): Promise<Response> {
  try {
    const body = await parseJsonBody<CloudCaptionRequest>(request, 512_000);
    const input = validateCaptionRequest(body);
    const plan = resolveEffectivePlan(input.plan, env.DEFAULT_PLAN ?? "beta");
    input.plan = plan;

    if (!canConsumeQuota(input.appUserId, input.requestId, plan)) {
      return errorResponse("quota_exceeded", "Daily cloud enhancement quota has been used.", 429);
    }

    const captions = makeMockCaptions(input);
    const remainingQuota = consumeQuota(input.appUserId, input.requestId, plan);

    const response: CloudCaptionResponse = {
      captions,
      provider: env.DEFAULT_PROVIDER ?? "mock",
      model: "mock-v1",
      inputTokens: 0,
      outputTokens: 0,
      estimatedCost: 0,
      remainingQuota
    };

    return jsonResponse(response);
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Cloud caption enhancement failed.", 500);
  }
}
