import type {
  CloudCaptionRequest,
  Plan,
  TrainingContributionConsentRequest,
  TrainingContributionSampleRequest
} from "../types/api";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validPlans = new Set(["free", "beta", "plus", "pro"]);
const validContributionKinds = new Set(["photo", "caption"]);
const validContributionSources = new Set(["cloudEnhancement", "share", "copy", "manual"]);
const validConsentDecisions = new Set(["granted", "declined"]);

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

  if (input.imageUploadEnabled) {
    throw new ValidationError("image_upload_disabled", "Image upload is not enabled for contribution samples.");
  }

  validateNonEmptyString(input.privacyPolicyVersion, "missing_privacy_policy_version", "privacyPolicyVersion is required.");
  validateNonEmptyString(input.locale, "missing_locale", "locale is required.");
  validateNonEmptyString(input.originalPhotoRetention, "missing_retention", "originalPhotoRetention is required.");
  validateNonEmptyString(input.createdAt, "missing_created_at", "createdAt is required.");

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

function validateUUID(value: unknown, code: string, message: string): void {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new ValidationError(code, message);
  }
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

export class ValidationError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}
