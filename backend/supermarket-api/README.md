# Supermarket API Backend

Core Spring Boot API for Skopje Price Compass. This page follows the same documentation style as the repository main page and focuses on backend ownership, status, and contracts.

## Documentation Scope

- This README documents backend behavior, interfaces, and quality state.
- Secret values and environment-specific credentials are intentionally excluded.
- Operational notes here are implementation-facing, not deployment playbooks.

## Backend Goal

Provide a single authoritative API for:

1. Authentication and authorization
2. Product/supermarket catalog reads
3. Crowd submissions and evidence upload
4. Moderation review/edit/decision workflow
5. Cart comparison logic
6. Contributor rewards and leaderboard

## Current Status (At a Glance)

### Implemented

- JWT auth (`register`, `login`) with role-aware authorization
- Public catalog endpoints for products, details, and supermarkets
- Submission intake for product, price, and image evidence
- Admin moderation queue/detail with approve/reject and payload patching
- Moderation audit history (`submission_edits` + review history endpoint)
- Rewards stats, leaderboard, and recompute operation
- AI-assisted submission draft/review endpoints with deterministic fallback
- CSV import pipeline with dry-run and commit stages

### Partially Implemented / In Progress

- Production-grade AI prompt/version lifecycle governance is still lightweight
- E2E integration test depth for full moderation/rewards chains is not complete
- Deployment hardening documentation is present but not finalized as a runbook

### Next Work for Capstone Polish

- Expand negative-path integration tests (conflicts, malformed payloads, AI unavailable)
- Strengthen operational guardrails and alerting docs
- Finalize release/rollback checklist documentation

## Architecture Overview

### Primary Modules

- Controllers: `api/v1/auth`, `catalog`, `cart`, `submissions`, `moderation`, `rewards`, `imports`
- Security: `SecurityConfig`, `JwtAuthenticationFilter`, `JwtService`
- Services: `SubmissionService`, `ModerationService`, `CartComparisonService`, `RewardsService`, `AiAnalysisService`
- Persistence: Spring Data JPA + Flyway migrations in `src/main/resources/db/migration`

### Data/Migration Baseline

- Core schema: `V1__create_core_schema.sql`
- Seed/demo catalog and prices: `V2__seed_catalog_and_prices.sql`
- Advanced moderation/rewards/import/AI support: `V3__advanced_backend_features.sql`

## API Contract Summary

### Public/User-Facing

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/products`
- `GET /api/v1/products/{id}`
- `GET /api/v1/supermarkets`
- `POST /api/v1/cart/compare/single-supermarket`
- `POST /api/v1/submissions/product`
- `POST /api/v1/submissions/price`
- `POST /api/v1/submissions/images`
- `GET /api/v1/submissions/me`

### Admin

- `GET /api/v1/admin/submissions` (paged list with status/type/q/page/size/sort)
- `GET /api/v1/admin/submissions/{id}`
- `PATCH /api/v1/admin/submissions/{id}/payload`
- `GET /api/v1/admin/submissions/{id}/history`
- `POST /api/v1/admin/submissions/{id}/ai-review`
- `POST /api/v1/admin/submissions/{id}/approve`
- `POST /api/v1/admin/submissions/{id}/reject`
- `GET /api/v1/rewards/me`
- `GET /api/v1/rewards/leaderboard`
- `POST /api/v1/admin/rewards/recompute`
- `POST /api/v1/admin/imports/catalog/dry-run`
- `POST /api/v1/admin/imports/catalog/commit`
- `GET /api/v1/admin/imports/{jobId}`

### Moderation Patch Behavior

`PATCH /api/v1/admin/submissions/{id}/payload` accepts:

```json
{
  "payload": { "...": "replacement payload object" },
  "editReason": "optional note",
  "expectedUpdatedAt": "2026-04-17T20:00:00Z"
}
```

- Allowed only for `PENDING` submissions
- Uses optimistic concurrency when `expectedUpdatedAt` is supplied
- Persists audit history in `submission_edits`

## Operational Notes

### Runtime

From `backend/supermarket-api`:

```powershell
$env:SPRING_PROFILES_ACTIVE='local'
$env:DB_URL='jdbc:postgresql://localhost:5432/supermarket_db'
$env:APP_UPLOADS_DIR='uploads'
$env:MANAGEMENT_PORT='8081'
mvn spring-boot:run -DskipTests
```

- Default profile requires explicit `DB_USERNAME`, `DB_PASSWORD`, `APP_JWT_SECRET`, and `APP_ADMIN_BOOTSTRAP_TOKEN`.
- `local` profile provides development-only defaults for those values.
- Admin bootstrap registration is disabled by default; enable only for controlled local/test use via `APP_AUTH_ALLOW_ADMIN_BOOTSTRAP_REGISTRATION=true`.

### Upload Storage

- Uses `APP_UPLOADS_DIR` / `app.uploads.directory`
- Validated at startup (directory can be created and written)
- Container recommendation: persistent mount at `/var/lib/supermarket/uploads`

### Observability

- Actuator exposed on `MANAGEMENT_PORT` (default `8081`)
- Anonymous endpoints: `/actuator/health` (and probe paths), `/actuator/info`
- Admin-authenticated endpoints: `/actuator/metrics`, `/actuator/prometheus`
- Includes `liveness`/`readiness` probes and upload-storage health contributor

### Optional AI Config

- `APP_OPENAI_API_KEY`
- `APP_OPENAI_MODEL` (default `gpt-5.4-mini`)
- `APP_OPENAI_CHAT_COMPLETIONS_URL`
- `APP_OPENAI_TIMEOUT_MS`
- `APP_OPENAI_IMAGE_DETAIL` (default `high`; accepts `low`, `high`, or `auto`)
- `APP_AI_PROMPT_VERSION`

If key/config is absent, AI endpoints return deterministic `UNAVAILABLE`-style responses and core submission flows continue.

## Testing and Quality Snapshot

- Tests are under `src/test/java/...`
- Typical checks:

```powershell
mvn test
mvn verify
```

- Current gap: broader cross-feature integration coverage for moderation conflict and import edge-cases

## Related Documentation

- Root project overview: `../../README.md`
- Spring scaffold note: `./HELP.md`
