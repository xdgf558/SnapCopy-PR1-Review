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

export type CloudCaptionResponse = {
  captions: string[];
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
  originalPhotoRetention: string;
  createdAt: string;
  notes?: string | null;
};

export type ContributionStorageMode = "metadata-only-mock" | "d1-metadata-only";

export type TrainingContributionResponse = {
  accepted: boolean;
  consentId: string;
  sampleId?: string;
  storageMode: ContributionStorageMode;
  retentionPolicy: string;
  message: string;
};
