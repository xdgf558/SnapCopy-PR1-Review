# D1 Storage Plan

SnapCopy Cloud now uses Cloudflare D1 as the first persistent backend store.

## Current Scope

D1 stores structured metadata only:

- anonymous `appUserId`
- current mock/beta plan
- daily cloud enhancement usage
- cloud enhancement request logs
- contribution consent records
- contribution sample metadata
- final caption text only when the user explicitly taps Contribute

D1 does not store:

- original photos
- image files
- location metadata from photos
- provider API keys
- full user profiles
- login credentials

## Tables

- `app_users`
- `daily_usage`
- `cloud_request_logs`
- `training_contribution_consents`
- `training_contribution_samples`

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

`/api/contributions/sample` stores metadata-only samples after consent. Image upload is still rejected.

Storage modes:

- `d1-metadata-only`: D1 binding is active and the record was persisted.
- `metadata-only-mock`: D1 binding is unavailable and the route used local fallback behavior.

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

After this is stable, the next backend step is connecting a real caption provider while continuing to send only `sceneJson`, user preference JSON, locale, and target platform.
