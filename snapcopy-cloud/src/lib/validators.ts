import type {
  CloudCaptionRequest,
  CloudVisionRequest,
  Plan,
  SceneRecognitionRecordRequest,
  TrainingContributionConsentRequest,
  TrainingContributionSampleRequest,
  TrainingDatasetVersionRequest,
  UserFeedbackRecordRequest
} from "../types/api";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validPlans = new Set(["free", "beta", "plus", "pro"]);
const validContributionKinds = new Set(["photo", "caption"]);
const validContributionSources = new Set(["cloudEnhancement", "share", "copy", "manual"]);
const validConsentDecisions = new Set(["granted", "declined"]);
const validVisionMimeTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const validPredictionSources = new Set(["vision", "ocr", "customModel", "userCorrection", "ruleBased", "cloudVision"]);
const validFeedbackActions = new Set([
  "rating",
  "copyCaption",
  "shareCaption",
  "saveCaption",
  "regenerate",
  "deleteCaption",
  "markExternalGoodFeedback"
]);
const validDatasetTypes = new Set(["image_scene_classifier", "caption_strategy", "caption_model", "other"]);
const validDatasetStatuses = new Set(["draft", "exported", "training", "trained", "archived"]);
const sha256Pattern = /^[a-f0-9]{64}$/i;

export async function parseJsonBody<T>(request: Request, maxBytes: number): Promise<T> {
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > maxBytes) {
    throw new ValidationError("body_too_large", "Request body is too large.");
  }

  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maxBytes) {
    throw new ValidationError("body_too_large", "Request body is too large.");
  }

  try {
    return JSON.parse(rawBody) as T;
  } catch {
    throw new ValidationError("invalid_json", "Request body must be valid JSON.");
  }
}

export function normalizePlan(value: unknown, fallback: Plan): Plan {
  if (typeof value === "string" && validPlans.has(value)) {
    return value as Plan;
  }

  return fallback;
}

export function resolveEffectivePlan(value: unknown, fallback: Plan): Plan {
  const requestedPlan = normalizePlan(value, fallback);
  if (fallback === "beta" && requestedPlan === "free") {
    return "beta";
  }

  return requestedPlan;
}

export function validateCaptionRequest(input: CloudCaptionRequest): CloudCaptionRequest {
  if (!input || typeof input !== "object") {
    throw new ValidationError("invalid_request", "Request body is required.");
  }

  if (!uuidPattern.test(input.appUserId)) {
    throw new ValidationError("invalid_app_user_id", "appUserId must be a UUID.");
  }

  if (!uuidPattern.test(input.requestId)) {
    throw new ValidationError("invalid_request_id", "requestId must be a UUID.");
  }

  if (input.imageUploadEnabled) {
    throw new ValidationError("image_upload_disabled", "Image upload is not enabled for caption enhancement.");
  }

  if (typeof input.sceneJson !== "string" || input.sceneJson.trim().length === 0) {
    throw new ValidationError("missing_scene_json", "sceneJson is required.");
  }

  if (new TextEncoder().encode(input.sceneJson).byteLength > 256_000) {
    throw new ValidationError("scene_json_too_large", "sceneJson must be 256KB or smaller.");
  }

  if (input.userPreferenceJson && new TextEncoder().encode(input.userPreferenceJson).byteLength > 128_000) {
    throw new ValidationError("preference_json_too_large", "userPreferenceJson must be 128KB or smaller.");
  }

  if (typeof input.targetPlatform !== "string" || input.targetPlatform.trim().length === 0) {
    throw new ValidationError("missing_target_platform", "targetPlatform is required.");
  }

  if (typeof input.locale !== "string" || input.locale.trim().length === 0) {
    throw new ValidationError("missing_locale", "locale is required.");
  }

  return input;
}

export function validateVisionRequest(input: CloudVisionRequest): CloudVisionRequest {
  if (!input || typeof input !== "object") {
    throw new ValidationError("invalid_request", "Request body is required.");
  }

  validateUUID(input.appUserId, "invalid_app_user_id", "appUserId must be a UUID.");
  validateUUID(input.requestId, "invalid_request_id", "requestId must be a UUID.");

  if (input.imageUploadEnabled !== true) {
    throw new ValidationError("image_upload_required", "Image understanding requires an uploaded image payload.");
  }

  validateNonEmptyString(input.imageBase64, "missing_image", "imageBase64 is required.");
  validateStringEnum(input.imageMimeType, validVisionMimeTypes, "invalid_image_mime_type", "imageMimeType is invalid.");

  if (new TextEncoder().encode(input.imageBase64).byteLength > 1_500_000) {
    throw new ValidationError("image_too_large", "imageBase64 must be 1.5MB or smaller.");
  }

  if (input.sceneJson && new TextEncoder().encode(input.sceneJson).byteLength > 256_000) {
    throw new ValidationError("scene_json_too_large", "sceneJson must be 256KB or smaller.");
  }

  if (input.userPreferenceJson && new TextEncoder().encode(input.userPreferenceJson).byteLength > 128_000) {
    throw new ValidationError("preference_json_too_large", "userPreferenceJson must be 128KB or smaller.");
  }

  validateNonEmptyString(input.targetPlatform, "missing_target_platform", "targetPlatform is required.");
  validateNonEmptyString(input.locale, "missing_locale", "locale is required.");

  return input;
}

export function validateContributionConsentRequest(
  input: TrainingContributionConsentRequest
): TrainingContributionConsentRequest {
  if (!input || typeof input !== "object") {
    throw new ValidationError("invalid_request", "Request body is required.");
  }

  validateUUID(input.appUserId, "invalid_app_user_id", "appUserId must be a UUID.");
  validateUUID(input.consentId, "invalid_consent_id", "consentId must be a UUID.");
  validateStringEnum(input.kind, validContributionKinds, "invalid_kind", "Contribution kind is invalid.");
  validateStringEnum(input.decision, validConsentDecisions, "invalid_decision", "Consent decision is invalid.");
  validateNonEmptyString(input.scope, "missing_scope", "Consent scope is required.");
  validateNonEmptyString(input.privacyPolicyVersion, "missing_privacy_policy_version", "privacyPolicyVersion is required.");
  validateNonEmptyString(input.locale, "missing_locale", "locale is required.");
  validateNonEmptyString(input.createdAt, "missing_created_at", "createdAt is required.");

  return input;
}

export function validateContributionSampleRequest(
  input: TrainingContributionSampleRequest
): TrainingContributionSampleRequest {
  if (!input || typeof input !== "object") {
    throw new ValidationError("invalid_request", "Request body is required.");
  }

  validateUUID(input.appUserId, "invalid_app_user_id", "appUserId must be a UUID.");
  validateUUID(input.consentId, "invalid_consent_id", "consentId must be a UUID.");
  validateUUID(input.sampleId, "invalid_sample_id", "sampleId must be a UUID.");
  validateStringEnum(input.kind, validContributionKinds, "invalid_kind", "Contribution kind is invalid.");
  validateStringEnum(input.source, validContributionSources, "invalid_source", "Contribution source is invalid.");

  if (input.consentGranted !== true) {
    throw new ValidationError("consent_required", "Sample contribution requires explicit user consent.");
  }

  validateNonEmptyString(input.privacyPolicyVersion, "missing_privacy_policy_version", "privacyPolicyVersion is required.");
  validateNonEmptyString(input.locale, "missing_locale", "locale is required.");
  validateNonEmptyString(input.originalPhotoRetention, "missing_retention", "originalPhotoRetention is required.");
  validateNonEmptyString(input.createdAt, "missing_created_at", "createdAt is required.");

  if (input.imageUploadEnabled) {
    if (input.kind !== "photo") {
      throw new ValidationError("invalid_image_sample_kind", "Only photo contributions can include image payloads.");
    }

    if (/original/i.test(input.originalPhotoRetention)) {
      throw new ValidationError("original_photo_not_allowed", "Original photo retention is not allowed.");
    }

    validateNonEmptyString(input.imageBase64, "missing_image", "imageBase64 is required when imageUploadEnabled is true.");
    validateStringEnum(
      input.imageMimeType,
      validVisionMimeTypes,
      "invalid_image_mime_type",
      "imageMimeType is invalid."
    );

    if (new TextEncoder().encode(input.imageBase64 ?? "").byteLength > 1_500_000) {
      throw new ValidationError("image_too_large", "Compressed contribution image must be 1.5MB or smaller.");
    }

    validateOptionalPositiveInteger(input.imageWidth, "invalid_image_width", "imageWidth must be a positive integer.");
    validateOptionalPositiveInteger(input.imageHeight, "invalid_image_height", "imageHeight must be a positive integer.");

    if (input.imageSha256 !== undefined && input.imageSha256 !== null && !sha256Pattern.test(input.imageSha256)) {
      throw new ValidationError("invalid_image_sha256", "imageSha256 must be a SHA-256 hex digest.");
    }
  }

  if (input.sceneJson && new TextEncoder().encode(input.sceneJson).byteLength > 256_000) {
    throw new ValidationError("scene_json_too_large", "sceneJson must be 256KB or smaller.");
  }

  if (input.captionText && new TextEncoder().encode(input.captionText).byteLength > 16_000) {
    throw new ValidationError("caption_too_large", "captionText must be 16KB or smaller.");
  }

  if (input.sceneTags && input.sceneTags.length > 24) {
    throw new ValidationError("too_many_scene_tags", "sceneTags can contain at most 24 items.");
  }

  if (
    input.sceneConfidence !== undefined &&
    input.sceneConfidence !== null &&
    (typeof input.sceneConfidence !== "number" || input.sceneConfidence < 0 || input.sceneConfidence > 1)
  ) {
    throw new ValidationError("invalid_scene_confidence", "sceneConfidence must be between 0 and 1.");
  }

  return input;
}

export function validateSceneRecognitionRecordRequest(
  input: SceneRecognitionRecordRequest
): SceneRecognitionRecordRequest {
  if (!input || typeof input !== "object") {
    throw new ValidationError("invalid_request", "Request body is required.");
  }

  validateUUID(input.appUserId, "invalid_app_user_id", "appUserId must be a UUID.");
  validateUUID(input.recordId, "invalid_record_id", "recordId must be a UUID.");
  validateOptionalUUID(input.sampleId, "invalid_sample_id", "sampleId must be a UUID.");
  validateOptionalUUID(input.requestId, "invalid_request_id", "requestId must be a UUID.");
  validateStringEnum(input.source, validPredictionSources, "invalid_source", "Prediction source is invalid.");
  validateNonEmptyString(input.createdAt, "missing_created_at", "createdAt is required.");
  validateOptionalConfidence(input.confidence, "invalid_confidence", "confidence must be between 0 and 1.");
  validateOptionalPositiveInteger(input.latencyMs, "invalid_latency", "latencyMs must be a positive integer.");
  validateOptionalPositiveInteger(input.imageWidth, "invalid_image_width", "imageWidth must be a positive integer.");
  validateOptionalPositiveInteger(input.imageHeight, "invalid_image_height", "imageHeight must be a positive integer.");

  if (input.sceneJson && new TextEncoder().encode(input.sceneJson).byteLength > 256_000) {
    throw new ValidationError("scene_json_too_large", "sceneJson must be 256KB or smaller.");
  }

  if (input.top3Scenes && input.top3Scenes.length > 3) {
    throw new ValidationError("too_many_scene_candidates", "top3Scenes can contain at most 3 items.");
  }

  return input;
}

export function validateUserFeedbackRecordRequest(input: UserFeedbackRecordRequest): UserFeedbackRecordRequest {
  if (!input || typeof input !== "object") {
    throw new ValidationError("invalid_request", "Request body is required.");
  }

  validateUUID(input.appUserId, "invalid_app_user_id", "appUserId must be a UUID.");
  validateUUID(input.feedbackId, "invalid_feedback_id", "feedbackId must be a UUID.");
  validateOptionalUUID(input.sampleId, "invalid_sample_id", "sampleId must be a UUID.");
  validateStringEnum(input.action, validFeedbackActions, "invalid_action", "Feedback action is invalid.");
  validateNonEmptyString(input.createdAt, "missing_created_at", "createdAt is required.");

  if (input.rating !== undefined && input.rating !== null && (!Number.isInteger(input.rating) || input.rating < 1 || input.rating > 5)) {
    throw new ValidationError("invalid_rating", "rating must be an integer from 1 to 5.");
  }

  if (
    input.rewardScore !== undefined &&
    input.rewardScore !== null &&
    (typeof input.rewardScore !== "number" || input.rewardScore < -5 || input.rewardScore > 5)
  ) {
    throw new ValidationError("invalid_reward_score", "rewardScore is outside the allowed range.");
  }

  if (input.metadata && new TextEncoder().encode(JSON.stringify(input.metadata)).byteLength > 64_000) {
    throw new ValidationError("metadata_too_large", "metadata must be 64KB or smaller.");
  }

  return input;
}

export function validateTrainingDatasetVersionRequest(
  input: TrainingDatasetVersionRequest
): TrainingDatasetVersionRequest {
  if (!input || typeof input !== "object") {
    throw new ValidationError("invalid_request", "Request body is required.");
  }

  validateNonEmptyString(input.datasetVersion, "missing_dataset_version", "datasetVersion is required.");
  validateStringEnum(input.datasetType, validDatasetTypes, "invalid_dataset_type", "datasetType is invalid.");

  if (input.status !== undefined) {
    validateStringEnum(input.status, validDatasetStatuses, "invalid_dataset_status", "status is invalid.");
  }

  validateOptionalPositiveInteger(input.sampleCount, "invalid_sample_count", "sampleCount must be a positive integer.");

  if (input.sourceFilter && new TextEncoder().encode(JSON.stringify(input.sourceFilter)).byteLength > 64_000) {
    throw new ValidationError("source_filter_too_large", "sourceFilter must be 64KB or smaller.");
  }

  if (input.sceneCounts && new TextEncoder().encode(JSON.stringify(input.sceneCounts)).byteLength > 64_000) {
    throw new ValidationError("scene_counts_too_large", "sceneCounts must be 64KB or smaller.");
  }

  return input;
}

function validateUUID(value: unknown, code: string, message: string): void {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new ValidationError(code, message);
  }
}

function validateOptionalUUID(value: unknown, code: string, message: string): void {
  if (value === undefined || value === null || value === "") {
    return;
  }

  validateUUID(value, code, message);
}

function validateNonEmptyString(value: unknown, code: string, message: string): void {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(code, message);
  }
}

function validateStringEnum(value: unknown, validValues: Set<string>, code: string, message: string): void {
  if (typeof value !== "string" || !validValues.has(value)) {
    throw new ValidationError(code, message);
  }
}

function validateOptionalConfidence(value: unknown, code: string, message: string): void {
  if (value === undefined || value === null) {
    return;
  }

  if (typeof value !== "number" || value < 0 || value > 1) {
    throw new ValidationError(code, message);
  }
}

function validateOptionalPositiveInteger(value: unknown, code: string, message: string): void {
  if (value === undefined || value === null) {
    return;
  }

  if (!Number.isInteger(value) || Number(value) <= 0) {
    throw new ValidationError(code, message);
  }
}

export class ValidationError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}
