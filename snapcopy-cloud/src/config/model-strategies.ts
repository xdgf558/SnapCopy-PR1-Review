export type StrategyMode = "balanced" | "quality";
export type StrategyPlan = "plus" | "pro";
export type StrategyPlatform = "x" | "instagram" | "threads" | "general";
export type StrategyLocale = "en" | "ja" | "zh-Hant" | "zh-Hans";

export interface ModelStrategy {
  name: StrategyMode;
  modelName: string;
  targetCostUsd: number;
  maxImageDimension: number;
  maxImageSizeBytes: number;
  maxPromptTokens: number;
  maxOutputTokens: number;
  captionCount: number;
  allowedPlatforms: StrategyPlatform[];
  allowedLocales: StrategyLocale[];
}

export const BALANCED_STRATEGY: ModelStrategy = {
  name: "balanced",
  // Placeholder until Phase 2 wires strategies into concrete AI providers.
  modelName: "placeholder",
  targetCostUsd: 0.0035,
  maxImageDimension: 1024,
  maxImageSizeBytes: 524288,
  maxPromptTokens: 2000,
  maxOutputTokens: 900,
  captionCount: 5,
  allowedPlatforms: ["x", "instagram", "threads", "general"],
  allowedLocales: ["en", "zh-Hans"]
};

export const QUALITY_STRATEGY: ModelStrategy = {
  name: "quality",
  // Placeholder until Phase 2 wires strategies into concrete AI providers.
  modelName: "placeholder",
  targetCostUsd: 0.0050,
  maxImageDimension: 2048,
  maxImageSizeBytes: 1048576,
  maxPromptTokens: 4000,
  maxOutputTokens: 2000,
  captionCount: 5,
  allowedPlatforms: ["x", "instagram", "threads", "general"],
  allowedLocales: ["en", "ja", "zh-Hant", "zh-Hans"]
};

export function getStrategy(mode: StrategyMode): ModelStrategy {
  return mode === "quality" ? QUALITY_STRATEGY : BALANCED_STRATEGY;
}

export function getStrategyForPlan(plan: StrategyPlan): ModelStrategy {
  return plan === "pro" ? QUALITY_STRATEGY : BALANCED_STRATEGY;
}
