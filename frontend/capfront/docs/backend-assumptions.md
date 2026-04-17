# Backend Assumptions and Gaps (Angular Web)

This frontend intentionally stays within currently available backend APIs.

## Moderation submission detail lookup

- There is no `GET /api/v1/admin/submissions/{id}` endpoint.
- Detail page (`/admin/submissions/:id`) resolves a submission by fetching:
  - `status=PENDING`
  - `status=APPROVED`
  - `status=REJECTED`
  and finding the requested id client-side.

## No submission edit/correct moderation endpoint

- Backend moderation API currently exposes only:
  - approve
  - reject
- There is no edit/correct endpoint for admin pre-approval payload changes.
- UI explicitly surfaces this limitation in moderation views.

## Evidence preview assumptions

- Evidence preview uses `payload.imageUrl` when present (typically product submissions).
- No dedicated moderation evidence endpoint exists.

## Public catalog list filters/sort

- Public products API supports search query `q`.
- Category/sort/pagination endpoints are not currently exposed.
- Additional sorting in web app is client-side only.
