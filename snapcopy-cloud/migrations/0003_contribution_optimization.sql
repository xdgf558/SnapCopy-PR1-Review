CREATE TABLE IF NOT EXISTS contribution_optimization_runs (
  run_id TEXT PRIMARY KEY,
  run_type TEXT NOT NULL,
  bucket_key TEXT NOT NULL,
  scene TEXT,
  locale TEXT,
  target_platform TEXT,
  sample_count INTEGER NOT NULL,
  edited_count INTEGER NOT NULL DEFAULT 0,
  share_count INTEGER NOT NULL DEFAULT 0,
  copy_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  summary_json TEXT NOT NULL,
  candidate_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_contribution_optimization_runs_bucket
  ON contribution_optimization_runs(bucket_key, created_at);

CREATE TABLE IF NOT EXISTS caption_strategy_candidates (
  candidate_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  bucket_key TEXT NOT NULL,
  scene TEXT,
  locale TEXT,
  target_platform TEXT,
  strategy_json TEXT NOT NULL,
  sample_count INTEGER NOT NULL,
  confidence REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending_review',
  created_at TEXT NOT NULL,
  reviewed_at TEXT,
  FOREIGN KEY (run_id) REFERENCES contribution_optimization_runs(run_id)
);

CREATE INDEX IF NOT EXISTS idx_caption_strategy_candidates_status
  ON caption_strategy_candidates(status, scene, locale, target_platform, created_at);
