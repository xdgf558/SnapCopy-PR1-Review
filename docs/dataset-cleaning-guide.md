# Dataset Cleaning Guide

This guide explains how to clean the first 260 images and prepare training copies for v2.

## Core Principle

Never delete or overwrite the first 260 original images. Keep `v1_raw` as an archive and write every decision into manifests.

## v1 Raw Manifest

Fill `ml-dataset/manifests/v1_raw_manifest.csv`:

```csv
image_id,file_path,original_label,source_type,created_at,notes
```

`source_type` values:

- `real`
- `synthetic`
- `screenshot`
- `collage`
- `unknown`

## v1 Clean Manifest

Fill `ml-dataset/manifests/v1_clean_manifest.csv`:

```csv
image_id,old_file_path,new_file_path,original_label,correct_label,keep_or_remove,remove_reason,quality_tags,secondary_scenes,split,notes
```

`keep_or_remove` values:

- `keep`
- `remove`
- `review`

`remove_reason` values:

- `wrong_label_unfixable`
- `duplicate`
- `too_ambiguous`
- `too_low_quality`
- `privacy_sensitive`
- `not_relevant`
- `other`

`quality_tags` values can be combined with commas:

- `low_light`
- `blurry`
- `overexposed`
- `backlight`
- `cluttered`
- `weird_angle`
- `partial_subject`
- `screenshot`
- `collage`
- `text_overlay`
- `compressed`
- `normal`

## Keep

Keep images that are:

- Correctly labeled normal photos.
- Clearly fixable by changing the label.
- Useful hard cases: low light, mild blur, clutter, weird angle, partial subject, screenshot, collage, text overlay, compression.
- Realistic photos that users may upload in normal use.

## Remove Or Reject

Remove from training, or put into a rejected folder outside the training split, when:

- The file is an obvious duplicate.
- The main subject is completely unclear.
- The scene cannot be assigned even after review.
- The label is not fixable.
- The image contains private user information without permission.
- The image is unrelated to all 13 classes.

## Image Copies

1. Keep originals untouched.
2. Create training copies from kept images.
3. Resize training copies so the long edge is 768 to 1280 px.
4. Use jpg or png.
5. Keep each training copy around 200KB to 1.5MB when practical.
6. Do not use tiny 200px images as the main training source.

## File Naming

Use:

```text
{scene}_{source}_{quality}_{index}.jpg
```

Examples:

```text
breakfast_real_normal_0001.jpg
cafe_synthetic_low_light_0021.jpg
walking_real_weird_angle_0045.jpg
pet_synthetic_partial_subject_0032.jpg
```

## v1 Split

If the 260 images are usable:

- train: about 180
- validation: about 40
- test: about 40

Once the test split is fixed, do not keep reshuffling it. Use the same test split to compare future model versions.

## Leakage Rules

- Similar photos from the same burst should stay in one split.
- Same place, same meal, same pet sequence, or same prompt batch should not be split across train and test.
- Synthetic variations from one prompt should stay in one split.
