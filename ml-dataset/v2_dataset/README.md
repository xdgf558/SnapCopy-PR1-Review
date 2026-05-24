# v2_dataset

Create ML training dataset for the second local scene classifier.

Target size:

- Minimum: 13 classes x 80 images = about 1040 images
- Stronger target: 13 classes x 100 to 120 images = about 1300 to 1560 images

Split:

- `train/`: 70%
- `validation/`: 15%
- `test/`: 15%

Rules:

- Keep similar burst photos, same-location images, or generated variants in the same split.
- Do not let near-duplicates leak from train into test.
- Keep the test set fixed after v2 is established.
- Include both normal and hard examples in test.
- The `unknown` class should include real uncertain/mixed/ambiguous photos, not only garbage images.

Per class target at 100 images:

- 50 normal real photos
- 20 hard real photos
- 20 synthetic hard cases
- 10 special source images, such as screenshots, collages, compressed images, or text-overlaid images
