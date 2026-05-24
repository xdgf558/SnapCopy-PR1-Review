export type Plan = "free" | "beta" | "plus" | "pro";

export type CloudCaptionRequest = {
  appUserId: string;
  requestId: string;
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
  estimatedCost: number;
  remainingQuota: number;
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

export type TrainingContributionResponse = {
  accepted: boolean;
  consentId: string;
  sampleId?: string;
  storageMode: "metadata-only-mock";
  retentionPolicy: string;
  message: string;
};
