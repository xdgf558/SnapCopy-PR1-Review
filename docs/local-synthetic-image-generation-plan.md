# SnapCopy Local Synthetic Image Generation Plan

This document defines the local batch image generation workflow for the v2 scene recognition dataset.

Current status:

- v1 raw dataset: 260 images.
- v1 clean dataset: 249 usable images after first-pass cleaning.
- v2 target: 1,000 to 1,500 images.
- Synthetic images are supplemental and must stay clearly marked as synthetic.

## Why AI Images Are Only Supplemental

SnapCopy needs to recognize real user photos: casual phone shots, imperfect framing, mixed lighting, cluttered rooms, screenshots, collages, and ordinary everyday scenes.

AI images are useful because they can quickly cover rare hard cases, but they can also introduce model shortcuts:

- overly clean composition
- repeated AI texture
- unrealistic hands, faces, food, signs, mirrors, or UI
- too much “stock photo” style
- labels that are correct in the prompt but not obvious in the image

For v2, synthetic images should be used to fill gaps and stress-test confusing classes, not to replace real photos.

Recommended final v2 ratio:

- real photos: 65% to 75%
- synthetic images: 25% to 35%

If the target is 1,500 images:

- real photos: about 1,000
- Stable Diffusion 3.5 Medium: about 350
- FLUX.1 schnell: about 150

If real photos are temporarily unavailable, synthetic images can be used as a bootstrap layer, but they must remain marked as `source_type=synthetic` and should be replaced or balanced with real photos later.

## Model Roles

### Stable Diffusion 3.5 Medium

Use SD3.5 Medium as the main batch generator.

Best use:

- normal daily phone-like photos
- low light
- blurry and compressed samples
- cluttered rooms or tables
- weird angles
- partial subjects
- screenshots or text overlays
- collages
- overexposed photos

Target role in the 1,500-image plan:

- about 350 images
- broader coverage
- fast iteration
- less expensive review cycles

### FLUX.1 schnell

Use FLUX.1 schnell as a boutique supplement.

Best use:

- aesthetically stronger normal samples
- backlight samples
- high-quality but still realistic daily scenes
- confusing categories that need better visual anchors

Target role in the 1,500-image plan:

- about 150 images
- fewer, higher quality additions
- review more strictly so it does not become too polished

## Pilot Batch First

Do not generate 1,500 images in one pass.

Start with a pilot batch:

- 13 scenes
- 10 images per scene
- 130 total images

Pilot goals:

1. Confirm prompts produce realistic phone photos.
2. Confirm filenames and manifest rows match.
3. Check whether SD3.5 Medium and FLUX.1 schnell create class-specific visual signals.
4. Catch recurring artifacts before scaling.
5. Decide which prompts are worth expanding to 30 to 50 synthetic images per scene.

Pilot files:

- Manifest: `ml-dataset/manifests/v2_synthetic_pilot_manifest.csv`
- Prompt pack: `ml-dataset/generation_prompts/synthetic_pilot_batch_prompts.md`
- Generated image folder on the external drive: `/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/images/{scene}/`

The pilot manifest uses `split=pilot_review`. Do not train from those rows until the manual review is complete.

## Scenes

The 13 scene classes remain:

1. `breakfast`
2. `cafe`
3. `walking`
4. `street`
5. `travel`
6. `pet`
7. `outfit`
8. `fitness`
9. `sunset`
10. `home`
11. `work`
12. `food`
13. `unknown`

## Priority Confusion Pairs

Synthetic images should first help the categories that the model is likely to confuse:

- `breakfast` vs `food`
- `cafe` vs `breakfast`
- `walking` vs `street`
- `travel` vs `street`
- `home` vs `work`
- `outfit` vs `street`

Rules:

- Add obvious positive examples for each side.
- Add borderline examples only after enough clean examples exist.
- Keep labels based on what is visually dominant, not what the prompt says.

## Pilot Quality Coverage

Each scene gets 10 pilot rows. Across those 10 rows, all required quality tags are covered:

| Slot | Generator | Quality Tags | Purpose |
|---:|---|---|---|
| 1 | FLUX.1 schnell | `normal` | boutique normal sample |
| 2 | SD3.5 Medium | `low_light` | dim but recognizable |
| 3 | SD3.5 Medium | `blurry,compressed` | mild shake and compression |
| 4 | SD3.5 Medium | `cluttered` | messy real-life environment |
| 5 | SD3.5 Medium | `weird_angle` | casual awkward phone angle |
| 6 | SD3.5 Medium | `partial_subject` | cropped or partially visible subject |
| 7 | SD3.5 Medium | `screenshot,text_overlay` | screenshot-like special source |
| 8 | SD3.5 Medium | `collage` | multi-image collage |
| 9 | FLUX.1 schnell | `backlight` | polished but realistic backlight |
| 10 | SD3.5 Medium | `overexposed` | bright but still usable |

Extreme hard cases should not exceed 30% per scene.

For this workflow, these count as extreme or special-source hard cases:

- `blurry,compressed`
- `screenshot,text_overlay`
- `collage`

That means 3 of 10 pilot images per scene are extreme/special-source, exactly 30%.

## Sample Counts After Pilot

After the pilot passes manual review, expand synthetic images gradually.

Recommended next step:

- 30 synthetic images per class: 390 total
- then 40 to 50 per class only if quality is good

Per class at 50 synthetic images:

- SD3.5 Medium: about 35
- FLUX.1 schnell: about 15
- extreme/special-source hard cases: no more than 15

For the full 1,500 target:

- real photos should still become the majority
- use synthetic samples to patch low-coverage classes and confusion pairs
- never let synthetic images hide real-world test failures

## Filename Rules

Generated image filename:

`{scene}_{generator}_{quality}_{index}.jpg`

Examples:

- `breakfast_sd35_low_light_0001.jpg`
- `cafe_flux_normal_0001.jpg`
- `walking_sd35_blurry_compressed_0003.jpg`

Generator slugs:

- `sd35` = Stable Diffusion 3.5 Medium
- `flux` = FLUX.1 schnell

For multiple quality tags, join tags with `_` in the filename and with commas in the manifest:

- filename: `blurry_compressed`
- manifest: `blurry,compressed`

## Manifest Rules

Every generated image must have one manifest row.

Required fields:

```csv
image_id,file_path,source_type,generator,prompt,primary_scene,secondary_scenes,quality_tags,split,notes
```

Values:

- `source_type`: always `synthetic` for AI images.
- `generator`: `sd35_medium` or `flux1_schnell`.
- `primary_scene`: one of the 13 scene classes.
- `quality_tags`: comma-separated tags.
- `split`: start as `pilot_review`; after approval, change to `train`, `validation`, or `test`.
- `notes`: review notes, rejection reason, or special handling.

Do not put generated images directly into `v2_dataset/train`, `validation`, or `test`. First save them under:

`/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/images/{scene}/`

Then review them and only move approved images into `v2_dataset`.

## Manual Review Workflow

For each generated image, answer these questions:

1. Does the image visually match `primary_scene`?
2. Is the quality tag actually visible?
3. Does it look like a real phone photo rather than a model demo?
4. Are there distorted hands, faces, animals, food, text, mirrors, or UI?
5. Would a real SnapCopy user plausibly upload this image?
6. Is it too similar to another generated image?
7. Is the scene confusing in a useful way, or just mislabeled?

Review decisions:

- `approve`: may enter v2.
- `fix_label`: move to a more accurate scene.
- `keep_for_unknown`: useful ambiguous image for `unknown`.
- `reject`: do not train.
- `regenerate`: prompt idea is useful but image failed.

## Images To Delete Or Reject

Reject images that contain:

- obvious AI artifacts
- distorted hands or faces
- unreadable fake text dominating the image
- fake app UI that looks unlike iOS screenshots
- unrealistic food texture
- animals with broken anatomy
- impossible mirror reflections
- too polished commercial advertising style
- extreme blur where the scene is not recognizable
- wrong primary scene
- near duplicates from the same prompt
- any private or sensitive content

Move rejected images outside training folders or leave them only in the pilot folder with manifest notes.

## How To Add Approved Images To v2_dataset

After review:

1. Keep the original generated file in `/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/images`.
2. Copy approved images into `ml-dataset/v2_dataset/{split}/{primary_scene}/`.
3. Rename only if the filename does not follow the naming rule.
4. Add or update the row in `ml-dataset/manifests/v2_manifest.csv`.
5. Change `split` from `pilot_review` to `train`, `validation`, or `test`.
6. Keep groups from the same prompt family in the same split to avoid leakage.

Suggested split for approved pilot images:

- mostly `train`
- a small number can go to `validation`
- avoid putting early synthetic pilot images into `test` unless they are realistic and important hard cases

The real-photo test set should remain the main benchmark.

## Local Generation Execution

This repository does not store model weights or generation software.

Recommended local setup:

1. Use ComfyUI, AUTOMATIC1111, Invoke, or another local SD/FLUX runner.
2. Load Stable Diffusion 3.5 Medium for bulk SD rows.
3. Load FLUX.1 schnell for rows with `generator=flux1_schnell`.
4. Open `ml-dataset/generation_prompts/synthetic_pilot_batch_prompts.md`.
5. Generate one image per prompt.
6. Save the output exactly to the `file_path` in `v2_synthetic_pilot_manifest.csv`.
7. Do not upscale or beautify unless that is part of the quality tag.

Suggested generation defaults:

- output format: JPG
- long side: 768 to 1280 px
- aspect ratios: mix square, portrait, and landscape
- avoid logos and watermarks
- keep prompt text in the manifest unchanged

## Scale-Up Gate

Only expand beyond the 130-image pilot if:

- at least 80% of pilot images are approved or fixable
- each scene has at least 6 approved pilot images
- special-source images are not visually absurd
- confusion pairs improve in manual review
- the model does not learn obvious AI style artifacts

If pilot quality is poor, fix prompts before generating more.
