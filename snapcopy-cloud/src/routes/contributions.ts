import { errorResponse, jsonResponse } from "../lib/response";
import {
  parseJsonBody,
  validateSceneRecognitionRecordRequest,
  validateContributionConsentRequest,
  validateContributionSampleRequest,
  validateUserFeedbackRecordRequest,
  ValidationError
} from "../lib/validators";
import type {
  SceneRecognitionRecordRequest,
  TrainingContributionConsentRequest,
  TrainingContributionResponse,
  TrainingContributionSampleRequest,
  UserFeedbackRecordRequest
} from "../types/api";
import {
  recordContributionConsent,
  recordContributionSample,
  recordSceneRecognition,
  recordUserFeedback
} from "../lib/d1Store";
import { storeTrainingImageIfPresent } from "../lib/r2Store";

const retentionPolicy =
  "Only explicitly contributed samples are stored. Original photos are never retained; optional image storage uses compressed training copies without location metadata.";

type Env = {
  DB?: D1Database;
  TRAINING_IMAGES?: R2Bucket;
};

export async function handleContributionConsent(request: Request, env: Env): Promise<Response> {
  try {
    const body = await parseJsonBody<TrainingContributionConsentRequest>(request, 64_000);
    const input = validateContributionConsentRequest(body);
    const storageMode = await recordContributionConsent(env, input);

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

export async function handleContributionSample(request: Request, env: Env): Promise<Response> {
  try {
    const body = await parseJsonBody<TrainingContributionSampleRequest>(request, 2_000_000);
    const input = validateContributionSampleRequest(body);
    const imageStorage = await storeTrainingImageIfPresent(env, input);
    const storageMode = await recordContributionSample(env, input, imageStorage);

    const response: TrainingContributionResponse = {
      accepted: true,
      consentId: input.consentId,
      sampleId: input.sampleId,
      storageMode,
      retentionPolicy,
      message:
        storageMode === "d1-r2-compressed-image"
          ? "Contribution sample accepted with compressed image copy for review."
          : "Contribution sample accepted for review."
    };

    return jsonResponse(response);
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Contribution sample request failed.", 500);
  }
}

export async function handleSceneRecognitionRecord(request: Request, env: Env): Promise<Response> {
  try {
    const body = await parseJsonBody<SceneRecognitionRecordRequest>(request, 320_000);
    const input = validateSceneRecognitionRecordRequest(body);
    const storageMode = await recordSceneRecognition(env, input);

    return jsonResponse({
      accepted: true,
      recordId: input.recordId,
      storageMode,
      message: "Scene recognition record accepted."
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "Scene recognition record request failed.", 500);
  }
}

export async function handleUserFeedbackRecord(request: Request, env: Env): Promise<Response> {
  try {
    const body = await parseJsonBody<UserFeedbackRecordRequest>(request, 128_000);
    const input = validateUserFeedbackRecordRequest(body);
    const storageMode = await recordUserFeedback(env, input);

    return jsonResponse({
      accepted: true,
      feedbackId: input.feedbackId,
      storageMode,
      message: "User feedback record accepted."
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse("internal_error", "User feedback record request failed.", 500);
  }
}
