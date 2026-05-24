CREATE TABLE IF NOT EXISTS app_users (
  app_user_id TEXT PRIMARY KEY,
  current_plan TEXT NOT NULL DEFAULT 'beta',
  app_account_token TEXT,
  first_seen_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_usage (
  app_user_id TEXT NOT NULL,
  usage_date TEXT NOT NULL,
  feature_type TEXT NOT NULL,
  plan TEXT NOT NULL,
  used_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (app_user_id, usage_date, feature_type),
  FOREIGN KEY (app_user_id) REFERENCES app_users(app_user_id)
);

CREATE TABLE IF NOT EXISTS cloud_request_logs (
  request_id TEXT PRIMARY KEY,
  app_user_id TEXT NOT NULL,
  usage_date TEXT NOT NULL,
  feature_type TEXT NOT NULL,
  plan TEXT NOT NULL,
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  status TEXT NOT NULL,
  remaining_quota INTEGER NOT NULL,
  scene_json_size INTEGER NOT NULL DEFAULT 0,
  preference_json_size INTEGER NOT NULL DEFAULT 0,
  image_upload_enabled INTEGER NOT NULL DEFAULT 0,
  locale TEXT NOT NULL,
  target_platform TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (app_user_id) REFERENCES app_users(app_user_id)
);

CREATE INDEX IF NOT EXISTS idx_cloud_request_logs_user_date
  ON cloud_request_logs(app_user_id, usage_date, feature_type);

CREATE TABLE IF NOT EXISTS training_contribution_consents (
  consent_id TEXT PRIMARY KEY,
  app_user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  decision TEXT NOT NULL,
  scope TEXT NOT NULL,
  privacy_policy_version TEXT NOT NULL,
  locale TEXT NOT NULL,
  created_at TEXT NOT NULL,
  received_at TEXT NOT NULL,
  FOREIGN KEY (app_user_id) REFERENCES app_users(app_user_id)
);

CREATE INDEX IF NOT EXISTS idx_training_contribution_consents_user
  ON training_contribution_consents(app_user_id, created_at);

CREATE TABLE IF NOT EXISTS training_contribution_samples (
  sample_id TEXT PRIMARY KEY,
  app_user_id TEXT NOT NULL,
  consent_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  source TEXT NOT NULL,
  privacy_policy_version TEXT NOT NULL,
  locale TEXT NOT NULL,
  target_platform TEXT,
  scene TEXT,
  scene_confidence REAL,
  scene_tags_json TEXT NOT NULL DEFAULT '[]',
  scene_json TEXT,
  caption_text TEXT,
  caption_was_edited INTEGER NOT NULL DEFAULT 0,
  image_upload_enabled INTEGER NOT NULL DEFAULT 0,
  original_photo_retention TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL,
  received_at TEXT NOT NULL,
  FOREIGN KEY (app_user_id) REFERENCES app_users(app_user_id),
  FOREIGN KEY (consent_id) REFERENCES training_contribution_consents(consent_id)
);

CREATE INDEX IF NOT EXISTS idx_training_contribution_samples_user
  ON training_contribution_samples(app_user_id, created_at);

CREATE INDEX IF NOT EXISTS idx_training_contribution_samples_scene
  ON training_contribution_samples(scene, kind, source);
