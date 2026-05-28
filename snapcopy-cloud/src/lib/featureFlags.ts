import { jsonResponse } from "./response";

export type CloudFeatureFlagEnv = {
  CLOUD_ENHANCEMENT_ENABLED?: string;
};

export function isCloudEnhancementEnabled(env: CloudFeatureFlagEnv): boolean {
  return (env.CLOUD_ENHANCEMENT_ENABLED ?? "true").toLowerCase() !== "false";
}

export function cloudEnhancementUnavailableResponse(): Response {
  return jsonResponse(
    {
      error: "cloud_enhancement_unavailable",
      message: "云端增强暂时繁忙"
    },
    { status: 503 }
  );
}

