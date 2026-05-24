# App Core ML Integration Guide

This guide explains how the local scene classifier fits into the current SnapCopy app.

## Current Flow

The app keeps the existing pipeline:

1. Apple Vision image labels
2. OCR text
3. Visual traits and feature flags
4. Optional custom Core ML scene classifier
5. User correction history
6. SceneResolver and SceneFusionEngine
7. Foundation Models caption generation

No cloud API is required for this stage.

## Existing App Modules

The project already has these modules:

- `CustomSceneClassifier`
- `CoreMLSceneClassifier`
- `SceneFusionEngine`
- `ImageRecognitionMetricsLogger`
- `ImageAnalyzer`
- `SceneResolver`
- `ImageAnalysisDebugView`

If no model is bundled, `CoreMLSceneClassifier` returns `disabled`, and the app continues with Vision + OCR + rules.

## Model Resource Name

The current classifier loads:

```swift
SnapCopySceneClassifier
```

If Create ML exports `CaptionSceneClassifier_v2.mlmodel`, either rename it to:

```text
SnapCopySceneClassifier.mlmodel
```

or update the resource name passed to `CoreMLSceneClassifier`.

## Expected DebugView Output

After selecting a photo, open `照片理解诊断`.

It should show:

- Vision labels and confidence
- OCR recognized text and confidence
- detected product features
- Core ML Top-3 predictions or disabled status
- SceneResolver result
- final scene
- confidence
- whether manual scene selection is recommended
- Foundation Models prompt
- Foundation Models raw result
- latest local metric record / caption rating status

## Fusion Strategy

Initial source weights:

When Core ML predictions exist:

- Core ML scene classifier: 60%
- Vision rules: 25%
- OCR clues: 5%
- User correction history: 10%

When Core ML is disabled:

- Vision rules: 80%
- OCR clues: 10%
- User correction history: 10%

Direct Vision-label scene hints may still be shown in debug as supporting evidence.

## Confidence Strategy

- `confidence >= 0.80`: use local result directly.
- `0.50 <= confidence < 0.80`: show Top-3 candidates and let the user choose when appropriate.
- `confidence < 0.50`: tell the user the app is not confident and suggest manual scene selection or future cloud enhanced recognition.

## Metrics

`ImageRecognitionMetricsLogger` stores local debug records only.

It records:

- predicted scene
- top 3 scenes
- user selected scene
- whether correction was needed
- caption rating
- model latency
- image size
- created time

Do not upload user photos or private preferences in this stage.
