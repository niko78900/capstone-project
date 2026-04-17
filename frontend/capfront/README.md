# Capfront (Angular Web Frontend)

Angular frontend for the capstone web scope:

- Limited **public read-only** product browsing
- **Admin moderation dashboard** for crowd-sourced submissions

This web app is intentionally not a second full consumer app. Consumer-first flows (cart, checkout, etc.) are handled by the mobile app scope.

## Scope Implemented

### Public routes

- `/products`
  - searchable catalog
  - client-side sort options (name, price low-high, price high-low)
  - loading/empty/error states
- `/products/:id`
  - product profile
  - nutrition section (when available)
  - verified prices table with best-offer emphasis
  - loading/empty/error states

### Admin routes

- `/admin/login`
  - admin-only sign-in
  - route-reason messaging for auth required/forbidden/session expired
- `/admin`
  - dashboard summary cards (pending/approved/rejected/total)
  - quick moderation actions
- `/admin/submissions`
  - moderation queue
  - status/type/text filters
  - sort controls
  - client-side pagination
  - evidence thumbnail/preview for image payloads
  - approve/reject actions
  - loading/empty/error/success states
- `/admin/submissions/:id`
  - full submission review page
  - flattened field-by-field payload view + raw JSON toggle
  - evidence/image preview when `payload.imageUrl` exists
  - approve/reject actions

## Tech stack

- Angular 20 standalone APIs
- Angular Material
- Reactive forms
- HttpClient + interceptor-based auth handling

## Run locally

From `frontend/capfront`:

```bash
npm install
npm start
```

The dev server uses `proxy.conf.json` to forward `/api` requests to `http://localhost:8080`.

## Build and test

```bash
npm run build
npm test -- --watch=false --browsers=ChromeHeadless
```

If Chrome/Chromium is not available, set `CHROME_BIN` accordingly.

## Auth behavior (high level)

- Admin routes are protected by `adminAuthGuard`.
- Non-admin access attempts redirect to `/admin/login` with context query params.
- Requests include bearer token when a session exists.
- On `401` for protected admin API traffic, session is cleared and user is redirected to login with `reason=sessionExpired`.
- Failed `/auth/login` requests do not force redirect loops.

## Backend endpoints used by web app

### Public catalog

- `GET /api/v1/products?q=...`
- `GET /api/v1/products/{id}`
- `GET /api/v1/supermarkets`

### Auth

- `POST /api/v1/auth/login`

### Admin moderation

- `GET /api/v1/admin/submissions?status=PENDING|APPROVED|REJECTED`
- `POST /api/v1/admin/submissions/{id}/approve`
- `POST /api/v1/admin/submissions/{id}/reject`

## Known backend/API gaps

See [docs/backend-assumptions.md](./docs/backend-assumptions.md).
