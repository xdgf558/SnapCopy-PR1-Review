# SnapCopy Training Data Pipeline

This pipeline prepares data for future Create ML or custom training jobs. It does not train models automatically.

## What Gets Stored

D1 stores:

- user contribution consent records
- contribution samples
- sample review status
- cloud image understanding records
- user feedback records
- dataset version records
- readiness alerts

R2 is reserved for:

- compressed image copies only
- only after explicit user contribution consent
- never original photos
- never location metadata or original filenames

## Review Status

Every sample starts as:

```text
pending
```

Allowed statuses:

- `pending`
- `approved`
- `rejected`
- `used_in_training`

Only `approved` samples count toward training readiness alerts.

## Admin Endpoints

All admin endpoints require:

```http
Authorization: Bearer <OPTIMIZATION_ADMIN_TOKEN>
```

## Admin Page

Open:

```text
https://snapcopy-cloud-api.yehao1105.workers.dev/admin
```

The page itself does not expose data. Enter the admin token in the page to load:

- open training readiness reminders;
- contribution sample counts by review status;
- pending / approved / rejected samples;
- sample review actions;
- bulk sample review actions;
- CSV / JSON export for the current filters;
- manual readiness check.

The admin page stores the token in the browser's local storage on your own device. Do not use it on a public or shared computer.

### Training Reminder Threshold

The admin page includes a `训练提醒阈值` field.

- Default value: `300`
- Allowed range: `10` to `10000`
- Storage: D1 table `training_admin_settings`
- Applies to: manual readiness checks and scheduled readiness checks

When the threshold is `300`, a scene creates a readiness reminder after it has at least 300 `approved` samples.

Update it from the admin page, or call:

```bash
curl -X POST \
  -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"trainingReadySceneThreshold":400}' \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/settings"
```

### Reminder Behavior

The first reminder stage is dashboard-based:

- the Worker creates rows in `training_readiness_alerts`;
- `/admin` shows a visible badge and reminder list;
- the page auto-refreshes once per minute;
- you can manually trigger the readiness check;
- you can mark reminders as acknowledged.

This does not send email yet.

### Export Samples

JSON:

```bash
curl -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/export?format=json&kind=photo&status=approved"
```

CSV:

```bash
curl -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/export?format=csv&kind=photo&status=approved"
```

Optional query fields:

- `format=json|csv`
- `kind=photo|caption`
- `status=pending|approved|rejected|used_in_training`
- `scene=pet`
- `limit=5000`

### Review Sample

```bash
curl -X POST \
  -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"sampleId":"<uuid>","reviewStatus":"approved","reviewedBy":"Station Cat"}' \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/review-sample"
```

### Bulk Review Samples

The admin page can select all samples on the current page and review them in one action.

The backend accepts at most 100 sample IDs per request:

```bash
curl -X POST \
  -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"sampleIds":["<uuid-1>","<uuid-2>"],"reviewStatus":"approved","reviewedBy":"Station Cat"}' \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/review-samples"
```

### Register Dataset Version

```bash
curl -X POST \
  -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"datasetVersion":"scene-v3","datasetType":"image_scene_classifier","status":"draft","sampleCount":300}' \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/dataset-version"
```

### Run Readiness Check

```bash
curl -X POST \
  -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/readiness/run"
```

### List Readiness Alerts

```bash
curl -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/readiness/alerts"
```

### Acknowledge Readiness Alert

```bash
curl -X POST \
  -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"alertId":"<alert-id>"}' \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/readiness/ack"
```

### List Samples for Review

```bash
curl -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/samples?status=pending&kind=photo&limit=50"
```

### Dashboard Summary

```bash
curl -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/summary"
```

## Readiness Rule

The first rule is intentionally simple:

```text
If a scene has at least the configured number of approved samples, create an open readiness alert.
```

Example:

```text
pet 类新增 300 张可用图片样本，可以人工审核并准备 v2026.05 训练。
```

This is only a reminder. The next steps are still manual:

1. export the samples;
2. inspect privacy and label quality;
3. split train / validation / test;
4. train in Create ML or a later training system;
5. evaluate the model;
6. ship a new `.mlmodel` only after review.

## R2 Setup

Create the bucket:

```bash
npx wrangler r2 bucket create snapcopy-training-images
```

Then uncomment this block in `wrangler.toml`:

```toml
[[r2_buckets]]
binding = "TRAINING_IMAGES"
bucket_name = "snapcopy-training-images"
```

Deploy after uncommenting.

## Privacy Rules

- Do not upload original photos.
- Do not store EXIF or location metadata.
- Do not store original filenames.
- Keep all samples anonymous through `appUserId`.
- Delete rejected image objects from R2 in a future review tool.
- Do not train automatically from pending samples.
