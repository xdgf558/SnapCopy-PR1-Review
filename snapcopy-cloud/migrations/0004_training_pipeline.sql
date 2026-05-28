ALTER TABLE training_contribution_samples
  ADD COLUMN review_status TEXT NOT NULL DEFAULT 'pending';

ALTER TABLE training_contribution_samples
  ADD COLUMN review_reason TEXT;

ALTER TABLE training_contribution_samples
  ADD COLUMN reviewed_at TEXT;

ALTER TABLE training_contribution_samples
  ADD COLUMN reviewed_by TEXT;

ALTER TABLE training_contribution_samples
  ADD COLUMN used_in_dataset_version TEXT;

ALTER TABLE training_contribution_samples
  ADD COLUMN r2_object_key TEXT;

ALTER TABLE training_contribution_samples
  ADD COLUMN image_mime_type TEXT;

ALTER TABLE training_contribution_samples
  ADD COLUMN image_width INTEGER;

ALTER TABLE training_contribution_samples
  ADD COLUMN image_height INTEGER;

ALTER TABLE training_contribution_samples
  ADD COLUMN image_byte_size INTEGER;

ALTER TABLE training_contribution_samples
  ADD COLUMN image_sha256 TEXT;

ALTER TABLE training_contribution_samples
  ADD COLUMN privacy_redaction_status TEXT NOT NULL DEFAULT 'metadata_only';

CREATE INDEX IF NOT EXISTS idx_training_contribution_samples_review
  ON training_contribution_samples(review_status, kind, scene, received_at);

CREATE INDEX IF NOT EXISTS idx_training_contribution_samples_dataset
  ON training_contribution_samples(used_in_dataset_version);

CREATE INDEX IF NOT EXISTS idx_training_contribution_samples_r2
  ON training_contribution_samples(r2_object_key);

CREATE TABLE IF NOT EXISTS scene_recognition_records (
  record_id TEXT PRIMARY KEY,
  app_user_id TEXT NOT NULL,
  sample_id TEXT,
  request_id TEXT,
  source TEXT NOT NULL,
  predicted_scene TEXT,
  top3_scenes_json TEXT NOT NULL DEFAULT '[]',
  user_selected_scene TEXT,
  was_user_correction_needed INTEGER NOT NULL DEFAULT 0,
  confidence REAL,
  scene_json TEXT,
  latency_ms INTEGER,
  image_width INTEGER,
  image_height INTEGER,
  created_at TEXT NOT NULL,
  FOREIGN KEY (app_user_id) REFERENCES app_users(app_user_id),
  FOREIGN KEY (sample_id) REFERENCES training_contribution_samples(sample_id)
);

CREATE INDEX IF NOT EXISTS idx_scene_recognition_records_scene
  ON scene_recognition_records(predicted_scene, source, created_at);

CREATE INDEX IF NOT EXISTS idx_scene_recognition_records_user
  ON scene_recognition_records(app_user_id, created_at);

CREATE TABLE IF NOT EXISTS user_feedback_records (
  feedback_id TEXT PRIMARY KEY,
  app_user_id TEXT NOT NULL,
  sample_id TEXT,
  caption_text_hash TEXT,
  action TEXT NOT NULL,
  reward_score REAL,
  scene TEXT,
  locale TEXT,
  target_platform TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  FOREIGN KEY (app_user_id) REFERENCES app_users(app_user_id),
  FOREIGN KEY (sample_id) REFERENCES training_contribution_samples(sample_id)
);

CREATE INDEX IF NOT EXISTS idx_user_feedback_records_user
  ON user_feedback_records(app_user_id, created_at);

CREATE INDEX IF NOT EXISTS idx_user_feedback_records_scene_action
  ON user_feedback_records(scene, action, created_at);

CREATE TABLE IF NOT EXISTS training_dataset_versions (
  dataset_version TEXT PRIMARY KEY,
  dataset_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  source_filter_json TEXT NOT NULL DEFAULT '{}',
  sample_count INTEGER NOT NULL DEFAULT 0,
  scene_counts_json TEXT NOT NULL DEFAULT '{}',
  notes TEXT,
  created_at TEXT NOT NULL,
  exported_at TEXT
);

CREATE TABLE IF NOT EXISTS training_dataset_items (
  dataset_version TEXT NOT NULL,
  sample_id TEXT NOT NULL,
  split TEXT NOT NULL,
  label TEXT,
  created_at TEXT NOT NULL,
  PRIMARY KEY (dataset_version, sample_id),
  FOREIGN KEY (dataset_version) REFERENCES training_dataset_versions(dataset_version),
  FOREIGN KEY (sample_id) REFERENCES training_contribution_samples(sample_id)
);

CREATE INDEX IF NOT EXISTS idx_training_dataset_items_label
  ON training_dataset_items(dataset_version, label, split);

CREATE TABLE IF NOT EXISTS training_readiness_alerts (
  alert_id TEXT PRIMARY KEY,
  alert_type TEXT NOT NULL,
  kind TEXT NOT NULL,
  scene TEXT NOT NULL,
  eligible_count INTEGER NOT NULL,
  threshold INTEGER NOT NULL,
  dataset_target TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  message TEXT NOT NULL,
  created_at TEXT NOT NULL,
  acknowledged_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_training_readiness_alerts_status
  ON training_readiness_alerts(status, kind, scene, created_at);
