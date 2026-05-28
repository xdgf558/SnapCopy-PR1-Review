# D1 Storage Plan

SnapCopy Cloud now uses Cloudflare D1 as the first persistent backend store.

## Current Scope

D1 stores privacy-safe structured data for cloud enhancement, contribution review, and future training preparation:

- anonymous `appUserId`
- current mock/beta plan
- daily cloud enhancement usage
- cloud enhancement request logs
- contribution consent records
- contribution sample metadata and review status
- final caption text only when the user explicitly taps Contribute
- cloud image understanding records
- user feedback records
- training dataset version records
- training readiness alerts

D1 does not store:

- original photos
- location metadata from photos
- provider API keys
- full user profiles
- login credentials

R2 is reserved for optional compressed image copies only after explicit user contribution consent. If the R2 binding is not configured, the Worker still accepts contribution metadata but does not store images.

## Tables

- `app_users`
- `daily_usage`
- `cloud_request_logs`
- `training_contribution_consents`
- `training_contribution_samples`
- `scene_recognition_records`
- `user_feedback_records`
- `training_dataset_versions`
- `training_dataset_items`
- `training_readiness_alerts`

Contribution sample review statuses:

- `pending`
- `approved`
- `rejected`
- `used_in_training`

## Quota Logic

`/api/cloud-enhance/caption` now consumes quota through D1 when the `DB` binding is present.

Current daily limits:

- `free`: 0
- `beta`: 3
- `plus`: 20
- `pro`: 50

Repeated `requestId` values do not double count.

If the D1 binding is missing during local development, the Worker falls back to the old in-memory mock quota store.

## Contribution Logic

`/api/contributions/consent` stores the user's explicit decision.

`/api/contributions/sample` stores samples after consent. Caption samples store the final caption plus metadata. Photo samples can store an optional compressed image copy only if:

- the user explicitly chose to contribute;
- the app sends a compressed training copy, not the original photo;
- the R2 `TRAINING_IMAGES` binding is configured.

Storage modes:

- `d1-metadata-only`: D1 binding is active and the record was persisted.
- `d1-r2-compressed-image`: D1 metadata was persisted and the compressed image copy was stored in R2.
- `d1-r2-not-configured`: D1 metadata was persisted, but R2 is not configured, so no image file was stored.
- `metadata-only-mock`: D1 binding is unavailable and the route used local fallback behavior.

## Admin Training Routes

All admin routes require:

```http
Authorization: Bearer <OPTIMIZATION_ADMIN_TOKEN>
```

Export approved samples:

```bash
curl -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/export?format=csv&kind=photo&status=approved"
```

Run readiness check manually:

```bash
curl -X POST -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/readiness/run"
```

List readiness alerts:

```bash
curl -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN" \
  "https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/training/readiness/alerts"
```

When a scene reaches the configured threshold, the Worker creates an alert such as:

```text
pet 类新增 300 张可用图片样本，可以人工审核并准备 v2026.05 训练。
```

This does not train a model automatically. It only reminds the developer to review, export, and prepare the next dataset.

## R2 Setup

Create the bucket:

```bash
npx wrangler r2 bucket create snapcopy-training-images
```

Then uncomment the `[[r2_buckets]]` block in `wrangler.toml` and deploy again.

The app should upload only a recompressed image generated from decoded pixels, so EXIF and location metadata are not included.

## Migration Commands

Apply migrations locally:

```bash
npm run d1:migrate:local
```

Apply migrations to Cloudflare D1:

```bash
npm run d1:migrate:remote
```

Deploy Worker:

```bash
npm run deploy
```

## Next Steps

After this is stable, the next backend step is wiring the app-side contribution upload for compressed images and building a small review dashboard or export workflow.
