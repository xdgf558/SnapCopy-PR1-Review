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
  "provider": "mock",
  "model": "mock-v1",
  "inputTokens": 0,
  "outputTokens": 0,
  "estimatedCost": 0,
  "remainingQuota": 2
}
```

Rules:

- `appUserId` and `requestId` are required UUIDs.
- `sceneJson` must be <= 20KB.
- `userPreferenceJson` must be <= 10KB.
- `imageUploadEnabled` must be false for this endpoint.
- Reused request IDs do not double count quota in the current in-memory mock.

## POST /api/cloud-enhance/vision

Currently returns disabled.

## GET /api/usage/status

Query:

```text
?appUserId=uuid&plan=beta
```
