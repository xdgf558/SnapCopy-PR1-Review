# synthetic_pilot

This folder is for the v2 synthetic image pilot batch.

Images are intentionally ignored by Git. Keep generated files on the external drive under:

`/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/images/{scene}/`

Track every generated image in:

`ml-dataset/manifests/v2_synthetic_pilot_manifest.csv`

If the external drive name changes, regenerate the manifest with:

`python3 ml-dataset/scripts/prepare_synthetic_pilot_manifest.py --image-root /Volumes/YOUR_DRIVE/SnapCopy_ML_Dataset/synthetic_pilot/images`

Pilot policy:

- Generate only 10 images per scene first, 130 total.
- Do not merge images into `v2_dataset` until manual review is complete.
- Keep rejected images out of training paths.
- Keep synthetic images marked as `source_type=synthetic`.
