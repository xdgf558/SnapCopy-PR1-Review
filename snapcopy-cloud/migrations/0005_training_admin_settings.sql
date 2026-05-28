CREATE TABLE IF NOT EXISTS training_admin_settings (
  setting_key TEXT PRIMARY KEY,
  setting_value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

INSERT INTO training_admin_settings (setting_key, setting_value, updated_at)
VALUES ('training_ready_scene_threshold', '300', datetime('now'))
ON CONFLICT(setting_key) DO NOTHING;
