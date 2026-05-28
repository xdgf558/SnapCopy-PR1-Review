# SnapCopy Contribution API

This beta API reserves the privacy-safe training contribution flow for later model improvement.

Current behavior:

- Users must explicitly choose "contribute" in the app before any sample request is sent.
- Original photos are never uploaded or retained.
- Photo contributions send scene metadata and can optionally send a compressed training copy after consent.
- Caption contributions send the final shared/edited caption plus metadata.
- The Worker persists accepted samples to D1 when the `DB` binding is available.
- Compressed image copies are stored in R2 only when the `TRAINING_IMAGES` binding is configured.
- Every contribution sample starts with `review_status = pending`.

Endpoints:

- `POST /api/contributions/consent`
- `POST /api/contributions/sample`
- `POST /api/contributions/scene-recognition`
- `POST /api/contributions/feedback`

Sample image rules:

1. The app must ask the user for contribution consent first.
2. The app must recompress the image from decoded pixels before upload.
3. Do not upload original files.
4. Do not include filename, location, or EXIF metadata.
5. If R2 is not configured, the Worker records metadata only and returns `d1-r2-not-configured`.

Admin review flow:

1. Contribution sample is stored as `pending`.
2. Developer reviews it and changes it to `approved` or `rejected`.
3. When exported into a dataset, the sample can be marked `used_in_training`.
4. Training readiness alerts are created only from `approved` samples.

Storage modes:

- `d1-metadata-only`
- `d1-r2-compressed-image`
- `d1-r2-not-configured`
- `metadata-only-mock`
