export type Plan = "free" | "beta" | "plus" | "pro";

export type CloudCaptionRequest = {
  appUserId: string;
  requestId: string;
  clientAppVersion?: string;
  clientBuild?: string;
  sceneJson: string;
  userPreferenceJson?: string | null;
  targetPlatform: string;
  locale: string;
  plan?: Plan;
  imageUploadEnabled: boolean;
  featureType?: string;
};

export type CloudVisionRequest = {
  appUserId: string;
  requestId: string;
  clientAppVersion?: string;
  clientBuild?: string;
  sceneJson?: string;
  userPreferenceJson?: string | null;
  targetPlatform: string;
  locale: string;
  plan?: Plan;
  imageUploadEnabled: boolean;
  featureType?: string;
  imageBase64: string;
  imageMimeType: "image/jpeg" | "image/png" | "image/webp";
};

export type CloudCaptionResponse = {
  captions: string[];
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  estimatedCost: number | null;
  remainingQuota: number;
};

export type CloudVisionSceneCandidate = {
  scene: string;
  confidence: number;
  reason?: string;
};

export type CloudVisionUnderstanding = {
  scene: string;
  subScene?: string | null;
  confidence: number;
  top3Scenes: CloudVisionSceneCandidate[];
  sceneTags: string[];
  captionFocus?: string | null;
  semanticSummary?: string | null;
  subjectCues: string[];
  objectCues: string[];
  actionCues: string[];
  relationshipCues: string[];
  atmosphereCues: string[];
  ocrTexts: string[];
  mustMentionCues: string[];
  avoidUnsupportedClaims: string[];
};

export type CloudVisionResponse = {
  understanding: CloudVisionUnderstanding;
  sceneJson: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  estimatedCost: number | null;
  remainingQuota: number;
};

export type ActiveCaptionStrategy = {
  version: string;
  scope?: {
    scene?: string;
    locale?: string;
    targetPlatform?: string;
  };
  signals?: Record<string, unknown>;
  promptGuidance?: string[];
  guardrails?: string[];
};

export type UsageStatusResponse = {
  plan: Plan;
  dailyLimit: number;
  usedToday: number;
  remainingQuota: number;
};

export type ApiErrorResponse = {
  error: {
    code: string;
    message: string;
  };
};

export type ContributionKind = "photo" | "caption";
export type ContributionSource = "cloudEnhancement" | "share" | "copy" | "manual";
export type ConsentDecision = "granted" | "declined";
export type ContributionImageMimeType = "image/jpeg" | "image/png" | "image/webp";
export type ContributionReviewStatus = "pending" | "approved" | "rejected" | "used_in_training";
export type PredictionSource = "vision" | "ocr" | "customModel" | "userCorrection" | "ruleBased" | "cloudVision";
export type FeedbackAction =
  | "rating"
  | "copyCaption"
  | "shareCaption"
  | "saveCaption"
  | "regenerate"
  | "deleteCaption"
  | "markExternalGoodFeedback";

export type TrainingContributionConsentRequest = {
  appUserId: string;
  consentId: string;
  kind: ContributionKind;
  decision: ConsentDecision;
  scope: string;
  privacyPolicyVersion: string;
  locale: string;
  createdAt: string;
};

export type TrainingContributionSampleRequest = {
  appUserId: string;
  consentId: string;
  sampleId: string;
  kind: ContributionKind;
  source: ContributionSource;
  consentGranted: boolean;
  privacyPolicyVersion: string;
  locale: string;
  targetPlatform?: string | null;
  scene?: string | null;
  sceneConfidence?: number | null;
  sceneTags?: string[];
  sceneJson?: string | null;
  captionText?: string | null;
  captionWasEdited?: boolean;
  imageUploadEnabled: boolean;
  imageBase64?: string | null;
  imageMimeType?: ContributionImageMimeType | null;
  imageWidth?: number | null;
  imageHeight?: number | null;
  imageSha256?: string | null;
  originalPhotoRetention: string;
  createdAt: string;
  notes?: string | null;
};

export type SceneRecognitionRecordRequest = {
  appUserId: string;
  recordId: string;
  sampleId?: string | null;
  requestId?: string | null;
  source: PredictionSource;
  predictedScene?: string | null;
  top3Scenes?: CloudVisionSceneCandidate[];
  userSelectedScene?: string | null;
  wasUserCorrectionNeeded?: boolean;
  confidence?: number | null;
  sceneJson?: string | null;
  latencyMs?: number | null;
  imageWidth?: number | null;
  imageHeight?: number | null;
  createdAt: string;
};

export type UserFeedbackRecordRequest = {
  appUserId: string;
  feedbackId: string;
  sampleId?: string | null;
  captionTextHash?: string | null;
  action: FeedbackAction;
  rating?: number | null;
  rewardScore?: number | null;
  scene?: string | null;
  locale?: string | null;
  targetPlatform?: string | null;
  metadata?: Record<string, unknown> | null;
  createdAt: string;
};

export type TrainingDatasetVersionRequest = {
  datasetVersion: string;
  datasetType: "image_scene_classifier" | "caption_strategy" | "caption_model" | "other";
  status?: "draft" | "exported" | "training" | "trained" | "archived";
  sourceFilter?: Record<string, unknown>;
  sampleCount?: number;
  sceneCounts?: Record<string, number>;
  notes?: string | null;
  exportedAt?: string | null;
};

export type ContributionStorageMode =
  | "metadata-only-mock"
  | "d1-metadata-only"
  | "d1-r2-compressed-image"
  | "d1-r2-not-configured";

export type TrainingContributionResponse = {
  accepted: boolean;
  consentId: string;
  sampleId?: string;
  storageMode: ContributionStorageMode;
  retentionPolicy: string;
  message: string;
};

export type CloudEnhancementUnit = "cloud_enhancement";

export type MonthlyUsageRecord = {
  appUserId: string;
  yearMonth: string;
  plan: Plan;
  usedUnits: number;
  updatedAt: string;
};

export type MonthlyQuotaResult = {
  allowed: boolean;
  remainingUnits: number;
  duplicateRequest: boolean;
};

export type MonthlyUsageStatusResponse = {
  plan: Plan;
  monthlyLimit: number;
  usedThisMonth: number;
  remainingMonthlyUnits: number;
};
