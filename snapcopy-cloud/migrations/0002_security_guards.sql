CREATE TABLE IF NOT EXISTS rate_limit_windows (
  scope_key TEXT NOT NULL,
  window_start TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (scope_key, window_start)
);

CREATE TABLE IF NOT EXISTS app_user_security_observations (
  app_user_id TEXT PRIMARY KEY,
  first_ip_hash TEXT NOT NULL,
  first_seen_date TEXT NOT NULL,
  first_seen_at TEXT NOT NULL,
  last_ip_hash TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_app_user_security_observations_ip_date
  ON app_user_security_observations(first_ip_hash, first_seen_date);

CREATE TABLE IF NOT EXISTS abuse_events (
  event_id TEXT PRIMARY KEY,
  app_user_id TEXT,
  request_id TEXT,
  ip_hash TEXT NOT NULL,
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  detail_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_abuse_events_type_created
  ON abuse_events(event_type, created_at);

