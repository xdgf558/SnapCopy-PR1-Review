# SnapCopy Scene Dataset

This folder manages local scene-recognition datasets for SnapCopy.

The app classifies everyday photos into 13 product scenes:

breakfast, cafe, walking, street, travel, pet, outfit, fitness, sunset, home, work, food, unknown.

## Version Policy

- `v1_raw/` keeps the first 260 images in their original state. Do not rename, overwrite, or delete these originals.
- `v1_clean/` contains cleaned copies or references after manual review, label correction, deduplication, and split assignment.
- `v2_dataset/` is the Create ML training dataset for the next model, targeting 1000 to 1500 images.
- `manifests/` is the source of truth for labels, splits, quality tags, and review decisions.
- `generation_prompts/` stores prompts for synthetic hard cases.
- `exports/` stores local `.mlmodel` exports from Create ML.

## Git Policy

Training images can be large or private. Do not commit user-private photos to a public repository.

By default, this folder tracks documentation and CSV manifests, while image files and exported model binaries are ignored. Keep image bodies on this Mac, an external drive, or private storage, and record their file paths in the manifests.

## Recommended Workflow

1. Put the original 260 images in `v1_raw/` or leave them in their current local folder and record paths in `manifests/v1_raw_manifest.csv`.
2. Review every v1 image and write the decision to `manifests/v1_clean_manifest.csv`.
3. Copy or export kept images into `v1_clean/` with corrected names.
4. Build `v2_dataset/train`, `v2_dataset/validation`, and `v2_dataset/test` from clean v1 images plus new real and synthetic images.
5. Train with Create ML and export `CaptionSceneClassifier_v2.mlmodel` to `exports/`.
6. Add the exported model to the iOS app only after evaluation passes the target metrics.

See `docs/` for the cleaning, expansion, training, evaluation, and Core ML integration guides.
