# Local Create ML Training Guide

This guide is written for a non-coding workflow on a Mac.

Goal: train the first usable local scene classifier with Apple Create ML, export a `.mlmodel`, and add it to the iOS app.

## 1. Prepare The Data Folder

Use this structure:

```text
ml-dataset/v2_dataset/
  train/
    breakfast/
    cafe/
    walking/
    street/
    travel/
    pet/
    outfit/
    fitness/
    sunset/
    home/
    work/
    food/
    unknown/
  validation/
    breakfast/
    ...
  test/
    breakfast/
    ...
```

Each image goes into the folder matching its label.

Split ratio:

- train: 70%
- validation: 15%
- test: 15%

Keep the `test` folder untouched after it is fixed.

## 2. Open Create ML

Option A:

1. Open Xcode.
2. In the macOS menu bar, choose `Xcode`.
3. Choose `Open Developer Tool`.
4. Choose `Create ML`.

Option B:

Open the Create ML app directly from Applications if it is available.

## 3. Create A New Project

1. Click `File`.
2. Click `New Project`.
3. Choose `Image Classification`.
4. Click `Next`.
5. Name the project something like `SnapCopySceneClassifier_v2`.

## 4. Import Training Data

1. For Training Data, select `ml-dataset/v2_dataset/train`.
2. For Validation Data, select `ml-dataset/v2_dataset/validation`.
3. Do not use the `test` folder during training.

Create ML reads folder names as labels.

## 5. Train

1. Click `Train`.
2. Wait for training to finish.
3. Record:
   - training accuracy
   - validation accuracy
   - per-class accuracy if shown
   - confusion matrix if shown
   - model size
   - notes about classes that look weak

## 6. Evaluate With Test Set

Use `ml-dataset/v2_dataset/test` only for final evaluation.

Record:

- Top-1 accuracy
- Top-3 coverage if available
- per-class accuracy
- confusion matrix if Create ML provides it
- low-confidence ratio
- unknown false-positive rate

If Create ML does not show Top-3, use the App DebugView after adding the model and manually check Top-3 predictions there.

## 7. Export The Model

Export as:

```text
CaptionSceneClassifier_v2.mlmodel
```

Save to:

```text
ml-dataset/exports/
```

Because `.mlmodel` files can be large, they are ignored by Git in this project by default.

## 8. Add The Model To Xcode

1. Open `SnapCopy.xcodeproj`.
2. Drag `CaptionSceneClassifier_v2.mlmodel` into the `SnapCopy/MLModels/` folder in Xcode.
3. Check `Copy items if needed`.
4. Make sure the SnapCopy app target is checked.
5. Rename the model or update `CoreMLSceneClassifier` to load the new resource name.

Current app default resource name:

```swift
SnapCopySceneClassifier
```

So either:

- Rename the exported model to `SnapCopySceneClassifier.mlmodel`, or
- Change the resource name in `CoreMLSceneClassifier`.

## 9. Verify In The App

1. Run the app in Xcode.
2. Select a test photo.
3. Open `照片理解诊断`.
4. Check:
   - Vision labels
   - OCR text
   - Core ML model Top-3
   - SceneResolver result
   - final scene and confidence
   - whether manual selection is needed
   - whether the generated caption matches the photo

If no model is bundled, the app must still run with Vision + OCR + rules.
