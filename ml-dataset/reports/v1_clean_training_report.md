# v1_clean Create ML Training Report

- Model: `CaptionSceneClassifier_v1_clean.mlmodel`
- Dataset: `ml-dataset/v1_clean`
- Tool: Apple Create ML `MLImageClassifier`
- Feature extractor: `scenePrint(revision: 1)`
- Max iterations: 25
- Augmentation: none
- Training time: 2.9 seconds
- Output: `ml-dataset/exports/CaptionSceneClassifier_v1_clean.mlmodel`

## Accuracy

| Split | Classification Error | Accuracy |
|---|---:|---:|
| Training | 0.0000 | 100.00% |
| Validation | 0.2162 | 78.38% |
| Test | 0.1795 | 82.05% |

## Notes

- This is a small cleaned-v1 baseline, not the final v2 model.
- v1_clean is still imbalanced after removing prompt/screenshot artifacts; use it as a quick sanity model.
- Keep the test split stable for comparison with v2.
- For production-level scene recognition, expand toward 1,000-1,500 images before judging final accuracy.

## Train Counts

| Scene | Count |
|---|---:|
| breakfast | 12 |
| cafe | 12 |
| walking | 9 |
| street | 14 |
| travel | 12 |
| pet | 15 |
| outfit | 14 |
| fitness | 14 |
| sunset | 14 |
| home | 14 |
| work | 14 |
| food | 14 |
| unknown | 15 |
| **Total** | **173** |

## Validation Counts

| Scene | Count |
|---|---:|
| breakfast | 2 |
| cafe | 2 |
| walking | 3 |
| street | 3 |
| travel | 3 |
| pet | 3 |
| outfit | 3 |
| fitness | 3 |
| sunset | 3 |
| home | 3 |
| work | 3 |
| food | 3 |
| unknown | 3 |
| **Total** | **37** |

## Test Counts

| Scene | Count |
|---|---:|
| breakfast | 3 |
| cafe | 3 |
| walking | 3 |
| street | 3 |
| travel | 3 |
| pet | 3 |
| outfit | 3 |
| fitness | 3 |
| sunset | 3 |
| home | 3 |
| work | 3 |
| food | 3 |
| unknown | 3 |
| **Total** | **39** |
