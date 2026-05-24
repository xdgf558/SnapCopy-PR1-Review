import { corsHeaders } from "./cors";
import type { ApiErrorResponse } from "../types/api";

export function jsonResponse<T>(body: T, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(),
      ...(init.headers ?? {})
    }
  });
}

export function errorResponse(code: string, message: string, status = 400): Response {
  const body: ApiErrorResponse = {
    error: {
      code,
      message
    }
  };

  return jsonResponse(body, { status });
}
