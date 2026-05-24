# v1 Model Comparison Report

- Test set: `ml-dataset/v1_clean/test`
- Test images: 39
- Old model: `ml-dataset/exports/CaptionSceneClassifier_v1.mlmodel`
- Clean model: `ml-dataset/exports/CaptionSceneClassifier_v1_clean.mlmodel`

## Summary

| Model | Top-1 Correct | Top-1 Accuracy | Top-3 Correct | Top-3 Coverage |
|---|---:|---:|---:|---:|
| v1_before_cleaning | 32/39 | 82.05% | 38/39 | 97.44% |
| v1_clean | 32/39 | 82.05% | 38/39 | 97.44% |

## Delta

- Top-1 accuracy delta: +0.00 percentage points
- Top-3 coverage delta: +0.00 percentage points

## Per-Class Top-1 Accuracy

| Scene | Old | Clean | Delta |
|---|---:|---:|---:|
| breakfast | 3/3 100.00% | 3/3 100.00% | +0.00 pp |
| cafe | 3/3 100.00% | 3/3 100.00% | +0.00 pp |
| fitness | 3/3 100.00% | 3/3 100.00% | +0.00 pp |
| food | 2/3 66.67% | 2/3 66.67% | +0.00 pp |
| home | 2/3 66.67% | 1/3 33.33% | -33.33 pp |
| outfit | 3/3 100.00% | 3/3 100.00% | +0.00 pp |
| pet | 3/3 100.00% | 3/3 100.00% | +0.00 pp |
| street | 3/3 100.00% | 3/3 100.00% | +0.00 pp |
| sunset | 1/3 33.33% | 2/3 66.67% | +33.33 pp |
| travel | 2/3 66.67% | 1/3 33.33% | -33.33 pp |
| unknown | 2/3 66.67% | 2/3 66.67% | +0.00 pp |
| walking | 2/3 66.67% | 3/3 100.00% | +33.33 pp |
| work | 3/3 100.00% | 3/3 100.00% | +0.00 pp |