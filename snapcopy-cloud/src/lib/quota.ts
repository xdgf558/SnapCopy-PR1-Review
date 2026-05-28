import type { Plan } from "../types/api";

/* @deprecated 阶段 2 将整体替换为 monthlyQuota.ts */

type UsageRecord = {
  usedToday: number;
  requestIds: Set<string>;
};

const memoryUsage = new Map<string, UsageRecord>();

export function dailyLimitForPlan(plan: Plan): number {
  // TODO(Phase 1-2): Replace this beta-era daily quota with the monthly
  // Cloud Enhancement Unit model backed by D1 usage records.
  switch (plan) {
    case "free":
      return 0;
    case "beta":
      return 3;
    case "plus":
      return 20;
    case "pro":
      return 50;
  }
}

export function usageKey(appUserId: string, date = new Date()): string {
  return `usage:${appUserId}:${date.toISOString().slice(0, 10)}`;
}

export function getUsage(appUserId: string): UsageRecord {
  const key = usageKey(appUserId);
  const existing = memoryUsage.get(key);
  if (existing) {
    return existing;
  }

  const record = {
    usedToday: 0,
    requestIds: new Set<string>()
  };
  memoryUsage.set(key, record);
  return record;
}

export function canConsumeQuota(appUserId: string, requestId: string, plan: Plan): boolean {
  const usage = getUsage(appUserId);
  if (usage.requestIds.has(requestId)) {
    return true;
  }

  return usage.usedToday < dailyLimitForPlan(plan);
}

export function consumeQuota(appUserId: string, requestId: string, plan: Plan): number {
  const usage = getUsage(appUserId);
  if (!usage.requestIds.has(requestId)) {
    usage.requestIds.add(requestId);
    usage.usedToday = Math.min(usage.usedToday + 1, dailyLimitForPlan(plan));
  }

  return Math.max(0, dailyLimitForPlan(plan) - usage.usedToday);
}
