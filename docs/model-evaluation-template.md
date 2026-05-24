# Model Evaluation Template

Copy this template for every model training run.

## Summary

| Field | Value |
| --- | --- |
| model_version |  |
| dataset_version |  |
| train_image_count |  |
| validation_image_count |  |
| test_image_count |  |
| per_class_image_count |  |
| training_accuracy |  |
| validation_accuracy |  |
| test_accuracy |  |
| top3_coverage |  |
| unknown_false_positive_rate |  |
| low_confidence_rate |  |
| user_correction_rate |  |
| caption_match_rating |  |
| model_size_mb |  |
| average_latency_ms |  |
| device |  |
| notes |  |

## v2 Acceptance Targets

First acceptable stage:

- Top-1 accuracy: 70% to 80%
- Top-3 coverage: 85% to 90%

Second-stage target:

- Top-1 accuracy: 80% to 88%
- Top-3 coverage: 90% to 95%

Clear-scene target:

- Top-1 close to 90%

Product-level target:

- Local model + Top-3 user confirmation + future cloud enhancement should make perceived user accuracy exceed 90%.

## Per-Class Accuracy

| scene | test_count | top1_correct | top1_accuracy | top3_covered | top3_coverage | notes |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| breakfast |  |  |  |  |  |  |
| cafe |  |  |  |  |  |  |
| walking |  |  |  |  |  |  |
| street |  |  |  |  |  |  |
| travel |  |  |  |  |  |  |
| pet |  |  |  |  |  |  |
| outfit |  |  |  |  |  |  |
| fitness |  |  |  |  |  |  |
| sunset |  |  |  |  |  |  |
| home |  |  |  |  |  |  |
| work |  |  |  |  |  |  |
| food |  |  |  |  |  |  |
| unknown |  |  |  |  |  |  |

## Confusion Pairs

Track the most common wrong predictions:

| true_label | predicted_label | count | likely_reason | next_action |
| --- | --- | ---: | --- | --- |
| breakfast | food |  |  | add_more_samples |
| cafe | breakfast |  |  | add_more_samples |
| walking | street |  |  | add_more_samples |
| travel | street |  |  | add_more_samples |
| home | work |  |  | add_more_samples |
| outfit | street |  |  | add_more_samples |

## Error Review CSV

Use:

```text
ml-dataset/manifests/v2_error_review.csv
```

Fields:

```csv
image_id,file_path,true_label,predicted_label,top3_predictions,confidence,is_correct,error_type,notes,next_action
```

`error_type` values:

- `label_error`
- `ambiguous_scene`
- `low_light`
- `blurry`
- `cluttered`
- `partial_subject`
- `screenshot`
- `collage`
- `similar_class_confusion`
- `unknown_issue`
- `model_weakness`

`next_action` values:

- `fix_label`
- `add_more_samples`
- `move_to_unknown`
- `remove`
- `keep_for_hard_test`
- `cloud_enhancement_candidate`

The next dataset expansion should prioritize the categories and confusion pairs with the most errors.
