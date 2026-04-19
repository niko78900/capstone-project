# Backend Assumptions and Known Constraints (Angular Web)

This frontend consumes only existing backend endpoints and does not invent API behavior.

## Moderation list pagination metadata

- `GET /api/v1/admin/submissions` returns a paged envelope.
- Angular uses `items`, `totalElements`, `page`, `size`, and `totalPages` directly.
- Queue total is sourced from backend metadata, not from extra list calls.

## Moderation payload patching

- Admin payload patching is used only for `PENDING` submissions.
- Frontend sends `expectedUpdatedAt` and handles `409` conflict as stale-data reload.
- Field validation errors are rendered when backend returns `fieldErrors`.

## Moderation evidence preview

- Evidence preview relies on `payload.imageUrl` when present.
- There is no separate dedicated moderation evidence endpoint assumed by Angular.

## Public catalog filtering/sorting

- Public API supports search by `q`.
- Category and supermarket filters and sort order are handled client-side on fetched results.
- No backend-side public filtering/sorting/paging contract is assumed beyond current endpoints.
