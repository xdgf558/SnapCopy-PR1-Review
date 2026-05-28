CREATE TABLE IF NOT EXISTS monthly_usage (
  app_user_id TEXT NOT NULL,
  year_month TEXT NOT NULL,
  plan TEXT NOT NULL,
  used_units INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (app_user_id, year_month)
);

ALTER TABLE cloud_request_logs
  ADD COLUMN cost_usd REAL;

ALTER TABLE cloud_request_logs
  ADD COLUMN cloud_units_used INTEGER DEFAULT 1;

ALTER TABLE cloud_request_logs
  ADD COLUMN unit_type TEXT DEFAULT 'cloud_enhancement';
