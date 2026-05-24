import { errorResponse, jsonResponse } from "../lib/response";
import {
  parseJsonBody,
  validateContributionConsentRequest,
  validateContributionSampleRequest,
  ValidationError
} from "../lib/validators";
import type {
  TrainingContributionConsentRequest,
  TrainingContributionResponse,
  TrainingContributionSampleRequest
} from "../types/api";

const storageMode = "metadata-only-mock";
const retentionPolicy = "This beta build accepts consent and metadata only. Original photos are not uploaded.";

export async function handleContributionConsent(request: Request): Promise<Response> {
  try {
    const body = await parseJsonBody<TrainingContributionConsentRequest>(request, 64_000);
    const input = validateContributionConsentRequest(body);

    const response: TrainingContributionResponse = {
      accepted: true,
      consentId: input.consentId,
      storageMode,
      retentionPolicy,
      message: input.decision === "granted" ? "Consent accepted." : "Consent declined."
    };

    return jsonResponse(response);
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Contribution consent request failed.", 500);
  }
}

export async function handleContributionSample(request: Request): Promise<Response> {
  try {
    const body = await parseJsonBody<TrainingContributionSampleRequest>(request, 320_000);
    const input = validateContributionSampleRequest(body);

    const response: TrainingContributionResponse = {
      accepted: true,
      consentId: input.consentId,
      sampleId: input.sampleId,
      storageMode,
      retentionPolicy,
      message: "Contribution sample accepted for metadata-only beta review."
    };

    return jsonResponse(response);
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Contribution sample request failed.", 500);
  }
}
