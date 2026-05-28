import type { Plan } from "../types/api";

export const BETA_DAILY_LIMIT = 3;

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
