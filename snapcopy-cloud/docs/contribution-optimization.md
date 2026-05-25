# Contribution Optimization Loop

SnapCopy now treats anonymous contribution data as optimization material, not as an automatic model-training source.

## Recommended Thresholds

Do not wait for several thousand samples before learning anything. Use staged thresholds:

- 200 caption samples in the same scene + locale + platform bucket: generate a candidate strategy for review.
- 500 samples: candidate quality is usually stable enough to compare against current prompts.
- 1,000+ samples: consider promoting a reviewed strategy to active, or preparing a model-training dataset.
- 3,000+ samples: consider automated A/B testing and heavier model work.

The Worker default is `OPTIMIZATION_MIN_CAPTION_SAMPLES=200`.

## What Runs Automatically

The Worker has a daily cron trigger:

```toml
[triggers]
crons = ["0 18 * * *"]
```

This runs around 02:00 in China Standard Time. It scans D1 contribution samples and creates `pending_review` caption strategy candidates when a bucket has enough samples.

The automatic job does **not** train a model and does **not** immediately change production captions.

## Why Manual Review Still Matters

Contribution data can contain noisy captions, accidental shares, repeated wording, or weak scene recognition. The safe loop is:

1. Collect anonymous metadata and final caption samples with consent.
2. Automatically aggregate samples by scene, locale, and platform.
3. Create a strategy candidate.
4. Review the candidate.
5. Mark it `active` only after it looks useful.
6. Cloud caption prompts read active strategies at generation time.

## D1 Tables

- `training_contribution_samples`: raw contributed metadata and caption samples.
- `contribution_optimization_runs`: each optimizer run and its aggregate summary.
- `caption_strategy_candidates`: strategy candidates generated from aggregate signals.

`caption_strategy_candidates.status` values:

- `pending_review`: generated automatically, not used by production prompts.
- `active`: used by cloud caption generation.
- `rejected`: kept for audit but ignored.

## Manual Trigger

For development, the optimizer can be run manually:

```bash
curl -X POST https://snapcopy-cloud-api.yehao1105.workers.dev/api/admin/optimization/run \
  -H "Authorization: Bearer $OPTIMIZATION_ADMIN_TOKEN"
```

Set the token as a Worker secret:

```bash
npx wrangler secret put OPTIMIZATION_ADMIN_TOKEN
```

## What The Strategy Candidate Contains

The candidate stores aggregate signals only:

- sample count
- edited/share/copy ratios
- average caption length
- average scene confidence
- frequent scene tags
- prompt guidance
- guardrails

It does not duplicate full user captions inside the candidate.

## When Real Model Training Starts

Only start training when the dataset is explicitly suitable:

- users clearly consent to the training purpose
- enough samples per scene/language/platform bucket
- sensitive data policy is documented
- raw photos are only included if the user explicitly opted in
- EXIF/location data is stripped before storage

For now, caption optimization should happen through prompt strategy and provider behavior, not automatic model training.
