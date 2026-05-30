ALTER TABLE cloud_request_logs
  ADD COLUMN input_tokens INTEGER DEFAULT 0;

ALTER TABLE cloud_request_logs
  ADD COLUMN output_tokens INTEGER DEFAULT 0;

ALTER TABLE cloud_request_logs
  ADD COLUMN error_code TEXT;
