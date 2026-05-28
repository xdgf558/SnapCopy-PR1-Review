export type CostConfigEnv = {
  DAILY_GLOBAL_COST_LIMIT_USD?: string;
  MONTHLY_GLOBAL_COST_LIMIT_USD?: string;
  PLUS_MONTHLY_COST_ALERT_USD?: string;
  PRO_MONTHLY_COST_ALERT_USD?: string;
};

const defaults = {
  dailyGlobalCostLimitUSD: 50.0,
  monthlyGlobalCostLimitUSD: 1000.0,
  plusMonthlyCostAlertUSD: 0.8,
  proMonthlyCostAlertUSD: 4.0
};

export function getDailyGlobalCostLimit(env: CostConfigEnv): number {
  return numberFromEnv(env?.DAILY_GLOBAL_COST_LIMIT_USD, defaults.dailyGlobalCostLimitUSD);
}

export function getMonthlyGlobalCostLimit(env: CostConfigEnv): number {
  return numberFromEnv(env?.MONTHLY_GLOBAL_COST_LIMIT_USD, defaults.monthlyGlobalCostLimitUSD);
}

export function getPlusMonthlyCostAlert(env: CostConfigEnv): number {
  return numberFromEnv(env?.PLUS_MONTHLY_COST_ALERT_USD, defaults.plusMonthlyCostAlertUSD);
}

export function getProMonthlyCostAlert(env: CostConfigEnv): number {
  return numberFromEnv(env?.PRO_MONTHLY_COST_ALERT_USD, defaults.proMonthlyCostAlertUSD);
}

function numberFromEnv(value: string | undefined, fallback: number): number {
  if (value === undefined) {
    return fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}
