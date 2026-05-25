# SnapCopy Cloud API Contract

## POST /api/cloud-enhance/caption

Request body:

```json
{
  "appUserId": "uuid",
  "requestId": "uuid",
  "sceneJson": "{"scene":"cafe"}",
  "userPreferenceJson": "{}",
  "targetPlatform": "instagram",
  "locale": "zh-Hant",
  "plan": "beta",
  "imageUploadEnabled": false
}
```

Response body:

```json
{
  "captions": ["..."],
  "provider": "deepseek",
  "model": "deepseek-v4-flash",
  "inputTokens": 860,
  "outputTokens": 240,
  "estimatedCost": null,
  "remainingQuota": 2
}
```

Rules:

- `appUserId` and `requestId` are required UUIDs.
- `sceneJson` must be <= 20KB.
- `userPreferenceJson` must be <= 10KB.
- `imageUploadEnabled` must be false for this endpoint.
- Reused request IDs do not double count quota.
- When D1 is configured, quota is persisted in the backend database.
- Real text providers receive only `sceneJson`, `userPreferenceJson`, `targetPlatform`, and `locale`.
- Original photos are not uploaded.

Supported provider values:

- `mock`
- `gemini`
- `deepseek`
- `qwen`

## POST /api/cloud-enhance/vision

Currently returns disabled.

## GET /api/usage/status

Query:

```text
?appUserId=uuid&plan=beta
```

Returns D1-backed quota when the `DB` binding is configured.
