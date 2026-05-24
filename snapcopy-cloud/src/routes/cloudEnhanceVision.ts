import { jsonResponse } from "../lib/response";

export async function handleCloudEnhanceVision(): Promise<Response> {
  return jsonResponse({
    enabled: false,
    message: "Cloud image understanding is not enabled yet."
  });
}
