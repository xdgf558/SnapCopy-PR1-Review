# SnapCopy Contribution API

This beta API reserves the privacy-safe training contribution flow for later model improvement.

Current behavior:

- Users must explicitly choose "contribute" in the app before any sample request is sent.
- Original photos are not uploaded in this build.
- Photo contributions send scene metadata only, such as scene JSON, scene tags, confidence, locale, and target platform.
- Caption contributions send the final shared/edited caption plus metadata.
- The Worker currently returns a metadata-only mock acceptance response. It does not persist samples to a database yet.

Endpoints:

- `POST /api/contributions/consent`
- `POST /api/contributions/sample`

Future storage stages:

1. Add an explicit privacy notice and user-facing consent history.
2. Store consent and metadata in a backend table.
3. Add a short retention window for uploaded images only after image upload is enabled.
4. Strip EXIF and obvious private data before any training review.
5. Delete raw uploads after feature extraction or manual review, keeping only anonymous labels and derived metrics where possible.
