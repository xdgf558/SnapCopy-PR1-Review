import { hasD1, type D1Env } from "./d1Store";
import type { CaptionProviderName } from "../providers/captionProviders";
import type { CloudCaptionRequest, CloudVisionRequest, Plan } from "../types/api";

type SecurityEnv = D1Env & {
  RATE_LIMIT_USER_PER_MINUTE?: string;
  RATE_LIMIT_IP_PER_MINUTE?: string;
  MAX_NEW_USERS_PER_IP_PER_DAY?: string;
  MAX_REAL_PROVIDER_REQUESTS_PER_DAY?: string;
  SECURITY_HASH_SALT?: string;
};

export type SecurityDecision<ProviderName extends string = CaptionProviderName> =
  | {
      allowed: true;
      provider: ProviderName;
      notes: string[];
    }
  | {
      allowed: false;
      code: string;
      message: string;
      statusCode: number;
    };

type CloudSecurityRequest = Pick<
  CloudCaptionRequest | CloudVisionRequest,
  "appUserId" | "requestId" | "featureType"
>;

type RequestSecurityContext = {
  ipHash: string;
  userAgentHash: string;
};

type CountRow = {
  count: number;
};

type RateLimitRow = {
  request_count: number;
};

type ObservationRow = {
  app_user_id: string;
};

export async function enforceCloudCaptionSecurity(
  request: Request,
  env: SecurityEnv,
  input: CloudCaptionRequest,
  plan: Plan,
  provider: CaptionProviderName
): Promise<SecurityDecision> {
  return enforceCloudSecurity(request, env, input, plan, provider, "caption");
}

export async function enforceCloudVisionSecurity(
  request: Request,
  env: SecurityEnv,
  input: CloudVisionRequest,
  plan: Plan,
  provider: string
): Promise<SecurityDecision<string>> {
  return enforceCloudSecurity(request, env, input, plan, provider, "vision");
}

async function enforceCloudSecurity<ProviderName extends string>(
  request: Request,
  env: SecurityEnv,
  input: CloudSecurityRequest,
  plan: Plan,
  provider: ProviderName,
  featureScope: "caption" | "vision"
): Promise<SecurityDecision<ProviderName>> {
  const userLimitConfig = env.RATE_LIMIT_USER_PER_MINUTE;
  const ipLimitConfig = env.RATE_LIMIT_IP_PER_MINUTE;
  const newUsersLimitConfig = env.MAX_NEW_USERS_PER_IP_PER_DAY;
  const realProviderLimitConfig = env.MAX_REAL_PROVIDER_REQUESTS_PER_DAY;

  if (!hasD1(env)) {
    return {
      allowed: true,
      provider,
      notes: ["D1 unavailable; security guards are using app quota only."]
    };
  }

  const now = new Date();
  const context = await buildRequestSecurityContext(request, env, now);
  await observeAppUser(env.DB, input, context, now);

  const userLimit = parsePositiveInt(userLimitConfig, 6);
  const userRate = await incrementRateLimit(env.DB, `${featureScope}:user:${input.appUserId}`, userLimit, now);
  if (!userRate.allowed) {
    await recordAbuseEvent(env.DB, input, context, "user_rate_limited", "medium", {
      limit: userLimit,
      plan
    });
    return {
      allowed: false,
      code: "rate_limited",
      message: "Too many cloud enhancement requests. Please try again in a minute.",
      statusCode: 429
    };
  }

  const ipLimit = parsePositiveInt(ipLimitConfig, 30);
  const ipRate = await incrementRateLimit(env.DB, `${featureScope}:ip:${context.ipHash}`, ipLimit, now);
  if (!ipRate.allowed) {
    await recordAbuseEvent(env.DB, input, context, "ip_rate_limited", "high", {
      limit: ipLimit,
      plan
    });
    return {
      allowed: false,
      code: "rate_limited",
      message: "Too many cloud enhancement requests from this network. Please try again in a minute.",
      statusCode: 429
    };
  }

  const newUsersLimit = parsePositiveInt(newUsersLimitConfig, 20);
  const newUsersFromIp = await countNewUsersForIpToday(env.DB, context.ipHash, now);
  if (newUsersFromIp > newUsersLimit) {
    await recordAbuseEvent(env.DB, input, context, "many_new_users_from_ip", "high", {
      limit: newUsersLimit,
      count: newUsersFromIp,
      plan
    });
    return {
      allowed: false,
      code: "suspicious_activity",
      message: "Cloud enhancement is temporarily limited for this network.",
      statusCode: 429
    };
  }

  if (provider !== "mock") {
    const maxRealProviderRequests = parsePositiveInt(realProviderLimitConfig, 200);
    const realProviderCount = await countRealProviderRequestsToday(env.DB, now);
    if (realProviderCount >= maxRealProviderRequests) {
      await recordAbuseEvent(env.DB, input, context, "daily_provider_budget_exhausted", "high", {
        limit: maxRealProviderRequests,
        count: realProviderCount,
        provider,
        featureScope
      });
      return {
        allowed: true,
        provider: "mock" as ProviderName,
        notes: ["Daily real-provider safety cap reached; request will use mock fallback."]
      };
    }
  }

  return {
    allowed: true,
    provider,
    notes: []
  };
}

async function buildRequestSecurityContext(
  request: Request,
  env: SecurityEnv,
  now: Date
): Promise<RequestSecurityContext> {
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const userAgent = request.headers.get("User-Agent") ?? "unknown";
  const day = usageDateString(now);
  const salt = env.SECURITY_HASH_SALT ?? "snapcopy-security-v1";

  return {
    ipHash: await sha256Hex(`${salt}:ip:${day}:${ip}`),
    userAgentHash: await sha256Hex(`${salt}:ua:${userAgent}`)
  };
}

async function observeAppUser(
  db: D1Database,
  input: CloudSecurityRequest,
  context: RequestSecurityContext,
  now: Date
): Promise<void> {
  const existing = await db
    .prepare("SELECT app_user_id FROM app_user_security_observations WHERE app_user_id = ?")
    .bind(input.appUserId)
    .first<ObservationRow>();

  if (!existing) {
    await db
      .prepare(
        `INSERT INTO app_user_security_observations (
           app_user_id, first_ip_hash, first_seen_date, first_seen_at, last_ip_hash, last_seen_at
         )
         VALUES (?, ?, ?, ?, ?, ?)`
      )
      .bind(
        input.appUserId,
        context.ipHash,
        usageDateString(now),
        now.toISOString(),
        context.ipHash,
        now.toISOString()
      )
      .run();
    return;
  }

  await db
    .prepare(
      `UPDATE app_user_security_observations
       SET last_ip_hash = ?, last_seen_at = ?
       WHERE app_user_id = ?`
    )
    .bind(context.ipHash, now.toISOString(), input.appUserId)
    .run();
}

async function incrementRateLimit(
  db: D1Database,
  scopeKey: string,
  limit: number,
  now: Date
): Promise<{ allowed: boolean; count: number }> {
  const windowStart = minuteWindowStart(now);
  const row = await db
    .prepare("SELECT request_count FROM rate_limit_windows WHERE scope_key = ? AND window_start = ?")
    .bind(scopeKey, windowStart)
    .first<RateLimitRow>();

  const currentCount = row?.request_count ?? 0;
  if (currentCount >= limit) {
    return {
      allowed: false,
      count: currentCount
    };
  }

  const nextCount = currentCount + 1;
  await db
    .prepare(
      `INSERT INTO rate_limit_windows (scope_key, window_start, request_count, updated_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(scope_key, window_start)
       DO UPDATE SET
         request_count = excluded.request_count,
         updated_at = excluded.updated_at`
    )
    .bind(scopeKey, windowStart, nextCount, now.toISOString())
    .run();

  return {
    allowed: true,
    count: nextCount
  };
}

async function countNewUsersForIpToday(db: D1Database, ipHash: string, now: Date): Promise<number> {
  const row = await db
    .prepare(
      `SELECT COUNT(*) AS count
       FROM app_user_security_observations
       WHERE first_ip_hash = ? AND first_seen_date = ?`
    )
    .bind(ipHash, usageDateString(now))
    .first<CountRow>();

  return row?.count ?? 0;
}

async function countRealProviderRequestsToday(db: D1Database, now: Date): Promise<number> {
  const row = await db
    .prepare(
      `SELECT COUNT(*) AS count
       FROM cloud_request_logs
       WHERE usage_date = ? AND provider != 'mock' AND status = 'accepted'`
    )
    .bind(usageDateString(now))
    .first<CountRow>();

  return row?.count ?? 0;
}

async function recordAbuseEvent(
  db: D1Database,
  input: CloudSecurityRequest,
  context: RequestSecurityContext,
  eventType: string,
  severity: string,
  detail: Record<string, unknown>
): Promise<void> {
  await db
    .prepare(
      `INSERT INTO abuse_events (
         event_id, app_user_id, request_id, ip_hash, event_type, severity, detail_json, created_at
       )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      crypto.randomUUID(),
      input.appUserId,
      input.requestId,
      context.ipHash,
      eventType,
      severity,
      JSON.stringify({ ...detail, userAgentHash: context.userAgentHash }),
      new Date().toISOString()
    )
    .run();
}

function parsePositiveInt(value: string | undefined, fallback: number): number {
  if (!value) {
    return fallback;
  }

  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function usageDateString(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function minuteWindowStart(date: Date): string {
  const windowDate = new Date(date);
  windowDate.setUTCSeconds(0, 0);
  return windowDate.toISOString();
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
