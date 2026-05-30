import {
  getDailyGlobalCostLimit,
  getMonthlyGlobalCostLimit,
  getPlusMonthlyCostAlert,
  getProMonthlyCostAlert,
  type CostConfigEnv
} from "../config/cost-config";
import { getStrategy, getStrategyForPlan, type ModelStrategy } from "../config/model-strategies";
import { disableCloudEnhancementForCost } from "./featureFlags";
import { getGlobalCostSummary, getMonthlyCostSummary, type D1Env } from "./d1Store";
import type { Plan } from "../types/api";

type CostProtectionEnv = D1Env & CostConfigEnv;

const usersForcedToBalanced = new Set<string>();

export function strategyForCloudRequest(plan: Plan, appUserId: string): ModelStrategy {
  if (usersForcedToBalanced.has(appUserId)) {
    return getStrategy("balanced");
  }

  return getStrategyForPlan(plan === "pro" ? "pro" : "plus");
}

export async function applyCostProtectionAfterSuccess(
  env: CostProtectionEnv,
  input: {
    appUserId: string;
    plan: Plan;
    strategy: ModelStrategy;
    estimatedCostUsd: number | null;
  }
): Promise<void> {
  warnIfSingleRequestCostIsHigh(input);
  await warnAndDowngradeUserIfNeeded(env, input.appUserId, input.plan);
  await tripGlobalCircuitBreakerIfNeeded(env);
}

function warnIfSingleRequestCostIsHigh(input: {
  appUserId: string;
  plan: Plan;
  strategy: ModelStrategy;
  estimatedCostUsd: number | null;
}): void {
  const cost = input.estimatedCostUsd ?? 0;
  if (cost <= input.strategy.targetCostUsd) {
    return;
  }

  console.warn(
    `[COST_WARN] appUserId=${input.appUserId} plan=${input.plan} cost=${formatCost(cost)} target=${formatCost(
      input.strategy.targetCostUsd
    )}`
  );
}

async function warnAndDowngradeUserIfNeeded(
  env: CostProtectionEnv,
  appUserId: string,
  plan: Plan
): Promise<void> {
  if (plan !== "plus" && plan !== "pro") {
    return;
  }

  const month = new Date().toISOString().slice(0, 7);
  const summary = await getMonthlyCostSummary(env, appUserId, month);
  const alertLimit = plan === "pro" ? getProMonthlyCostAlert(env) : getPlusMonthlyCostAlert(env);
  if (summary.totalCost <= alertLimit) {
    return;
  }

  usersForcedToBalanced.add(appUserId);
  console.warn(
    `[USER_COST_WARN] appUserId=${appUserId} plan=${plan} monthlyCost=${formatCost(summary.totalCost)} alert=${formatCost(
      alertLimit
    )}; subsequent requests will use balanced strategy`
  );
}

async function tripGlobalCircuitBreakerIfNeeded(env: CostProtectionEnv): Promise<void> {
  const summary = await getGlobalCostSummary(env);
  const dailyLimit = getDailyGlobalCostLimit(env);
  const monthlyLimit = getMonthlyGlobalCostLimit(env);

  if (summary.dailyCost > dailyLimit) {
    const reason = `daily_global_cost_limit_exceeded:${formatCost(summary.dailyCost)}>${formatCost(dailyLimit)}`;
    console.warn(`[GLOBAL_COST_BREAKER] ${reason}`);
    await disableCloudEnhancementForCost(env, reason);
    return;
  }

  if (summary.monthlyCost > monthlyLimit) {
    const reason = `monthly_global_cost_limit_exceeded:${formatCost(summary.monthlyCost)}>${formatCost(monthlyLimit)}`;
    console.warn(`[GLOBAL_COST_BREAKER] ${reason}`);
    await disableCloudEnhancementForCost(env, reason);
  }
}

function formatCost(value: number): string {
  return Number.isFinite(value) ? value.toFixed(6).replace(/0+$/, "").replace(/\.$/, "") : "0";
}
