# v1_clean

Cleaned copy/reference layer for v1 images.

Current first-pass status:

- Source rows reviewed: 260
- Kept for clean inheritance: 249
- Removed from clean training inheritance: 11
- Review remaining: 0
- Images are materialized under `train/`, `validation/`, and `test/` by corrected scene label.
- Original files remain untouched in `模型训练相关/generated_scene_dataset/dataset`.

Use this folder after reviewing `v1_raw`:

- Keep correctly labeled images.
- Correct labels when the scene is clear.
- Preserve useful hard cases such as low light, blur, clutter, weird angles, partial subjects, screenshots, collages, and compressed photos.
- Move duplicates, unfixable labels, irrelevant images, and unauthorized private photos out of the training path.

Every decision must be recorded in `ml-dataset/manifests/v1_clean_manifest.csv`.

Suggested split for the 260-image v1 set, if quality is acceptable:

- train: about 180 images
- validation: about 40 images
- test: about 40 images

After the test split is fixed, keep it stable for model-to-model comparison.

Cleaning artifacts:

- Decision manifest: `ml-dataset/manifests/v1_clean_manifest.csv`
- Summary CSV: `ml-dataset/reports/v1_cleaning_summary.csv`
- Human review report: `ml-dataset/reports/v1_cleaning_report.md`
- Per-class contact sheets: `ml-dataset/reports/v1_cleaning_contact_sheets/`
