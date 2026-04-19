# Supermarket API Backend

Spring Boot backend for the capstone supermarket platform.

## Scope

- Auth (register/login, JWT)
- Public catalog (products, product detail, supermarkets)
- User submissions (product, price, image upload, my submissions)
- Admin moderation (queue, detail, approve/reject, payload patch audit, history)
- Cart single-supermarket comparison
- Rewards and contributor leaderboard
- AI-assisted draft extraction and moderation hints
- Admin CSV catalog import (dry-run and commit)

## Run

From `backend/supermarket-api`:

```powershell
$env:DB_URL='jdbc:postgresql://localhost:5432/supermarket_db'
$env:DB_USERNAME='postgres'
$env:DB_PASSWORD='postgres'
$env:APP_JWT_SECRET='replace_with_base64_secret'
$env:APP_ADMIN_BOOTSTRAP_TOKEN='CAPSTONE_ADMIN_SETUP'
mvn spring-boot:run -DskipTests
```

## AI Configuration

Optional AI extraction is enabled when `APP_OPENAI_API_KEY` is set.

- `APP_OPENAI_API_KEY`
- `APP_OPENAI_MODEL` (default `gpt-4.1-mini`)
- `APP_OPENAI_CHAT_COMPLETIONS_URL` (default `https://api.openai.com/v1/chat/completions`)
- `APP_OPENAI_TIMEOUT_MS` (default `15000`)
- `APP_AI_PROMPT_VERSION` (default `v1`)

If API key is missing, AI endpoints return deterministic `UNAVAILABLE` states and submission creation continues normally.

## Rewards Rules

- Approved `PRODUCT`: `+10`
- Approved `PRICE`: `+6`
- Approved `NUTRITION`: `+5`
- Rejected submission: `-2`

## CSV Import Templates

### Products import (`kind=PRODUCTS`)

Headers:

`barcode,name,brand,category,supermarket,price,imageUrl,calories,proteinG,carbsG,fatG,servingSize,observedAt,currency`

Minimum required:

`barcode,name,category,supermarket,price`

### Prices import (`kind=PRICES`)

Headers:

`productBarcode,productName,productBrand,supermarket,price,observedAt,currency`

Minimum required:

`supermarket,price` plus either `productBarcode` or `productName` (+ optional `productBrand`).

## Moderation Payload Patch Contract

Endpoint: `PATCH /api/v1/admin/submissions/{id}/payload`

Request body:

```json
{
  "payload": { "...": "replacement payload object" },
  "editReason": "optional note",
  "expectedUpdatedAt": "2026-04-17T20:00:00Z"
}
```

- Works only for `PENDING` submissions.
- Uses optimistic concurrency when `expectedUpdatedAt` is supplied.
- Saves an audit record in `submission_edits`.

## Moderation List Response Contract

`GET /api/v1/admin/submissions` now returns a paged envelope:

```json
{
  "items": [/* moderation rows */],
  "totalElements": 42,
  "page": 0,
  "size": 10,
  "totalPages": 5
}
```

## Key Endpoints Added

- `GET /api/v1/admin/submissions` (status/type/q/page/size/sort)
- `GET /api/v1/admin/submissions/{id}`
- `PATCH /api/v1/admin/submissions/{id}/payload`
- `GET /api/v1/admin/submissions/{id}/history`
- `POST /api/v1/admin/submissions/{id}/ai-review`
- `POST /api/v1/submissions/product/ai-draft`
- `GET /api/v1/rewards/me`
- `GET /api/v1/rewards/leaderboard`
- `POST /api/v1/admin/rewards/recompute`
- `POST /api/v1/admin/imports/catalog/dry-run`
- `POST /api/v1/admin/imports/catalog/commit`
- `GET /api/v1/admin/imports/{jobId}`
