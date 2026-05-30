import type { Plan } from "../types/api";
import {
  checkRequestIdExists,
  createMonthlyUsage,
  getCloudUnitRequestLog,
  getMonthlyUsage,
  getRemainingUnits,
  incrementCloudUnits,
  recordCloudUnitRequest,
  type QuotaStoreEnv
} from "./quotaStore";
import type { MonthlyQuotaResult } from "../types/api";

export const BETA_DAILY_LIMIT = 3;

export type CloudQuotaCheckInput = {
  appUserId: string;
  requestId: string;
  plan: Plan;
};

export type CloudUnitDeductionInput = CloudQuotaCheckInput & {
  provider: string;
  model: string;
  sceneJson?: string | null;
  userPreferenceJson?: string | null;
  imageUploadEnabled?: boolean;
  locale?: string;
  targetPlatform?: string;
};

export function monthlyLimitForPlan(plan: Plan): number {
  switch (plan) {
    case "plus":
      return 200;
    case "pro":
      return 1000;
    case "free":
      return 10;
    case "beta":
      return BETA_DAILY_LIMIT;
    default:
      return 0;
  }
}

export function lifetimeLimitForPlan(plan: Plan): number | null {
  switch (plan) {
    case "free":
      return 10;
    default:
      return null;
  }
}

export function canConsumeMonthlyUnit(usedUnits: number, plan: Plan): boolean {
  switch (plan) {
    case "free":
      return usedUnits < 10;
    default:
      return usedUnits < monthlyLimitForPlan(plan);
  }
}

export function currentYearMonth(): string {
  return new Date().toISOString().slice(0, 7);
}

export function billingPeriodForPlan(plan: Plan, date = new Date()): string {
  if (plan === "free") {
    return "LIFETIME";
  }

  if (plan === "beta") {
    return date.toISOString().slice(0, 10);
  }

  return date.toISOString().slice(0, 7);
}

export async function checkQuota(env: QuotaStoreEnv, input: CloudQuotaCheckInput): Promise<MonthlyQuotaResult> {
  const limit = monthlyLimitForPlan(input.plan);
  if (!env.DB) {
    return { allowed: true, remainingUnits: limit, duplicateRequest: false };
  }

  const existingRequest = await getCloudUnitRequestLog(env, input.requestId);
  if (existingRequest) {
    if (existingRequest.status === "quota_exceeded") {
      return {
        allowed: false,
        remainingUnits: 0,
        duplicateRequest: true
      };
    }

    if (isSuccessfulCloudRequestStatus(existingRequest.status)) {
      return {
        allowed: true,
        remainingUnits: existingRequest.remainingQuota,
        duplicateRequest: true
      };
    }
  }

  const billingPeriod = billingPeriodForPlan(input.plan);
  const usage = await ensureMonthlyUsage(env, input.appUserId, billingPeriod, input.plan, limit);
  const remainingUnits = Math.max(0, limit - usage.usedUnits);
  return {
    allowed: usage.usedUnits < limit,
    remainingUnits,
    duplicateRequest: false
  };
}

export async function deductUnit(env: QuotaStoreEnv, input: CloudUnitDeductionInput): Promise<MonthlyQuotaResult> {
  const limit = monthlyLimitForPlan(input.plan);
  if (!env.DB) {
    return { allowed: true, remainingUnits: Math.max(0, limit - 1), duplicateRequest: false };
  }

  const existingRequest = await getCloudUnitRequestLog(env, input.requestId);
  if (existingRequest) {
    if (existingRequest.status === "quota_exceeded") {
      return {
        allowed: false,
        remainingUnits: 0,
        duplicateRequest: true
      };
    }

    if (isSuccessfulCloudRequestStatus(existingRequest.status)) {
      return {
        allowed: true,
        remainingUnits: existingRequest.remainingQuota,
        duplicateRequest: true
      };
    }
  }

  const billingPeriod = billingPeriodForPlan(input.plan);
  await ensureMonthlyUsage(env, input.appUserId, billingPeriod, input.plan, limit);
  const incremented = await incrementCloudUnits(env, input.appUserId, billingPeriod, input.requestId, limit);
  if (!incremented) {
    await recordCloudUnitRequest(env, {
      ...input,
      billingPeriod,
      status: "quota_exceeded",
      remainingUnits: 0,
      cloudUnitsUsed: 0
    });
    return { allowed: false, remainingUnits: 0, duplicateRequest: false };
  }

  const remainingUnits = await getRemainingUnits(env, input.appUserId, billingPeriod, limit);
  await recordCloudUnitRequest(env, {
    ...input,
    billingPeriod,
    status: "accepted",
    remainingUnits,
    cloudUnitsUsed: 1
  });
  return { allowed: true, remainingUnits, duplicateRequest: false };
}

export async function ensureMonthlyUsage(
  env: QuotaStoreEnv,
  appUserId: string,
  billingPeriod: string,
  plan: Plan,
  limit: number
): Promise<{
  usedUnits: number;
}> {
  const existing = await getMonthlyUsage(env, appUserId, billingPeriod);
  if (existing) {
    return { usedUnits: existing.usedUnits };
  }

  await createMonthlyUsage(env, appUserId, billingPeriod, plan, limit);
  return { usedUnits: 0 };
}

export { checkRequestIdExists };

function isSuccessfulCloudRequestStatus(status: string): boolean {
  return status === "accepted" || status === "success";
}
