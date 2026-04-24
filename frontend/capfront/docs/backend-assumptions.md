# Backend Assumptions and Known Constraints (Angular Web)

Contract notes for `frontend/capfront` to stay aligned with backend behavior. This document complements the main README-style docs and captures interface assumptions that affect frontend implementation decisions.

## Scope

- Captures assumptions currently relied on by web features
- Lists known constraints that should not be silently changed backend-side
- Documents where frontend intentionally performs client-side behavior

## Moderation List Contract

- `GET /api/v1/admin/submissions` returns a paged envelope.
- Angular consumes `items`, `totalElements`, `page`, `size`, and `totalPages` directly.
- Queue totals/pagination come from server metadata, not from separate count calls.

## Moderation Patch Contract

- Payload patching is supported only for `PENDING` submissions.
- Frontend sends `expectedUpdatedAt` for optimistic concurrency.
- Backend `409` is treated as stale data and triggers reload behavior.
- Backend `fieldErrors` are surfaced to users (detail page and queue edit flow).

## Moderation Evidence Assumption

- Evidence preview is sourced from `payload.imageUrl` when present.
- No dedicated evidence API endpoint is assumed by Angular.

## Public Catalog Assumptions

- Backend supports search through `q`.
- Category/supermarket filters and sort order are currently client-side in web.
- No backend public paging/filter contract is assumed beyond the existing catalog endpoints.

## Change Management Note

If backend contracts change (response shape, moderation patch semantics, validation errors), update:

1. `frontend/capfront/src/app/core/services/*`
2. Feature-level specs in `src/app/**/*.spec.ts`
3. This assumptions document
