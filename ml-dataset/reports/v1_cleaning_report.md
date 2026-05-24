# v1 Dataset Cleaning Report

This is a first-pass cleaning report. Source images were not deleted or renamed.

## Status Summary

- Total manifest rows: 260
- Keep: 249
- Review: 0
- Remove: 11
- Missing files: 0
- Materialized v1_clean images: 249
- Images with possible near-duplicates: 10
- Manual overrides applied: 14

## Kept Per-Class Count

- breakfast: 17
- cafe: 17
- walking: 15
- street: 20
- travel: 18
- pet: 21
- outfit: 20
- fitness: 20
- sunset: 20
- home: 20
- work: 20
- food: 20
- unknown: 21

## Quality Tags

- blurry: 1
- compressed: 4
- low_light: 7
- normal: 248
- overexposed: 2

## Removed By Reason

- not_relevant: 11

## Contact Sheets

- [breakfast](ml-dataset/reports/v1_cleaning_contact_sheets/breakfast.jpg)
- [cafe](ml-dataset/reports/v1_cleaning_contact_sheets/cafe.jpg)
- [walking](ml-dataset/reports/v1_cleaning_contact_sheets/walking.jpg)
- [street](ml-dataset/reports/v1_cleaning_contact_sheets/street.jpg)
- [travel](ml-dataset/reports/v1_cleaning_contact_sheets/travel.jpg)
- [pet](ml-dataset/reports/v1_cleaning_contact_sheets/pet.jpg)
- [outfit](ml-dataset/reports/v1_cleaning_contact_sheets/outfit.jpg)
- [fitness](ml-dataset/reports/v1_cleaning_contact_sheets/fitness.jpg)
- [sunset](ml-dataset/reports/v1_cleaning_contact_sheets/sunset.jpg)
- [home](ml-dataset/reports/v1_cleaning_contact_sheets/home.jpg)
- [work](ml-dataset/reports/v1_cleaning_contact_sheets/work.jpg)
- [food](ml-dataset/reports/v1_cleaning_contact_sheets/food.jpg)
- [unknown](ml-dataset/reports/v1_cleaning_contact_sheets/unknown.jpg)

## Next Manual Pass

1. Open each contact sheet and look for wrong scene labels.
2. In `v1_clean_manifest.csv`, change `correct_label` for fixable wrong labels.
3. Set `keep_or_remove=remove` only for unfixable duplicates, privacy-sensitive images, or unusable images.
4. Keep useful hard cases, but mark their `quality_tags`.
