# Dataset v2 Expansion Plan

The first 260-image dataset is a validation set, not enough for a stable local scene classifier.

v2 target: 1000 to 1500 images.

## Size Targets

Minimum target:

- 13 classes x 80 images = 1040 images

Stronger target:

- 13 classes x 100 images = 1300 images
- 13 classes x 120 images = 1560 images

Each class should reach at least 80 images. Prefer 100+ images for confusing classes.

## Per-Class Composition At 100 Images

- 50 normal real photos
- 20 hard real photos
- 20 AI-generated hard samples
- 10 special source images, such as screenshots, collages, compressed images, or text-overlaid images

## Overall Ratio

- Real photos: 65% to 80%
- AI-generated photos: 20% to 35%
- Special source images: 5% to 10%

AI images are allowed for hard-case coverage, but they should not become the dataset majority.

## Priority Confusions To Fix

Prioritize data collection for the pairs that are likely to confuse captions:

- breakfast vs food
- cafe vs breakfast
- walking vs street
- travel vs street
- home vs work
- outfit vs street
- pet vs food
- sunset vs travel

## Hard Case Types

Add hard cases for every class:

- `low_light`
- `blurry`
- `partial_subject`
- `cluttered`
- `weird_angle`
- `screenshot`
- `collage`
- `text_overlay`
- `compressed`
- `backlight`
- `overexposed`

Keep extreme hard cases below 30% of the dataset.

## v2 Split

Use:

- train: 70%
- validation: 15%
- test: 15%

Requirements:

1. Similar images must not be split between train and test.
2. Same location, same subject, same burst, or same generation prompt batch should stay in one split.
3. Test should contain both normal images and hard images.
4. Unknown should contain realistic ambiguous images, not only garbage.
5. Freeze the test set after v2 is built.

## Source Strategy

1. Inherit clean v1 images.
2. Add personal test photos that do not contain sensitive private information.
3. Add consented user test photos only after clear permission.
4. Add synthetic hard cases where real hard cases are missing.
5. Add special source images that reflect real app uploads: screenshots, collages, compressed photos, photos with text overlays.

## Stop Conditions For v2

Start Create ML training when:

- Every class has at least 80 images.
- Each class has at least 10 hard cases.
- The test set has at least 10 images per class.
- The manifests are complete.
- Obvious duplicates are removed or grouped.
