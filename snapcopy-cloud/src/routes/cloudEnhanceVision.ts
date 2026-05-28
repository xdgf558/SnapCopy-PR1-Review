import { jsonResponse } from "../lib/response";

// @deprecated Phase 2 will merge vision and caption enhancement into a unified endpoint.
export async function handleCloudEnhanceVision(): Promise<Response> {
  return jsonResponse({
    enabled: false,
    message: "Cloud image understanding is not enabled yet."
  });
}
