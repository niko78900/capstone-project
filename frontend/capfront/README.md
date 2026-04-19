# Capfront (Angular Web Frontend)

Angular frontend for the capstone web scope:

- Limited **public read-only** catalog browsing
- **Admin moderation + rewards** dashboard

The Angular app intentionally stays admin-first on web. Consumer-heavy flows remain in mobile scope.

## Scope Implemented

### Public routes (no account required)

- `/products`
  - searchable catalog (`q`)
  - product cards with best verified price emphasis
  - category and best-price-supermarket filters
  - client-side sort (default/relevance, name, price asc/desc)
  - robust loading/empty/error states
- `/products/:id`
  - full product detail
  - best-offer hero callout
  - nutrition highlights
  - verified supermarket prices table (lowest highlighted)
  - loading/empty/error states

### Admin routes (guarded)

- `/admin/login`
  - admin-only sign-in
  - clear route-reason notices (`authRequired`, `forbidden`, `sessionExpired`)
- `/admin`
  - dashboard summary cards (pending/approved/rejected/total)
  - queue-health cards (oldest/newest pending, oldest age)
  - latest pending entries + quick links
  - top-contributors preview
- `/admin/submissions`
  - server-driven moderation queue (status/type/search/page/size/sort query params)
  - route-query synchronized filters
  - pending highlighting + status chips
  - AI hints summary when available
  - evidence preview for image payloads
  - side-by-side change preview with raw JSON toggle
  - approve/reject (pending-only; reject reason required)
- `/admin/submissions/:id`
  - direct detail load per id
  - typed payload editor by submission type (`PRODUCT`/`PRICE`/`NUTRITION`)
  - optimistic concurrency patch (`expectedUpdatedAt`)
  - conflict/validation handling with field-level feedback
  - review history timeline
  - manual AI review refresh
  - evidence preview + raw/flattened payload views
- `/admin/rewards`
  - contributor leaderboard (windowed)
  - current user reward stats
  - admin recompute action

## Tech stack

- Angular 20 standalone APIs
- Angular Material
- Signals + reactive forms
- HttpClient + interceptor-based auth handling

## Run locally

From `frontend/capfront`:

```bash
npm install
npm start
```

`proxy.conf.json` forwards `/api` traffic to `http://localhost:8080`.

## Build and test

```bash
npm run build
npm test -- --watch=false --browsers=ChromeHeadless
```

If Chrome/Chromium is unavailable on your machine, set `CHROME_BIN` to a valid browser executable.

## Auth behavior (high level)

- Public product pages are open.
- Admin pages are protected by `adminAuthGuard`.
- Non-admin or unauthenticated access to admin routes redirects to `/admin/login` with context.
- Bearer token is attached when a session exists.
- `401` on protected admin API calls clears session and redirects to login with `reason=sessionExpired`.

## Backend endpoints used by web app

### Public catalog

- `GET /api/v1/products?q=...`
- `GET /api/v1/products/{id}`
- `GET /api/v1/supermarkets`

### Auth

- `POST /api/v1/auth/login`

### Moderation

- `GET /api/v1/admin/submissions?status=&type=&q=&page=&size=&sort=`
- `GET /api/v1/admin/submissions/{id}`
- `PATCH /api/v1/admin/submissions/{id}/payload`
- `GET /api/v1/admin/submissions/{id}/history`
- `POST /api/v1/admin/submissions/{id}/ai-review`
- `POST /api/v1/admin/submissions/{id}/approve`
- `POST /api/v1/admin/submissions/{id}/reject`

### Rewards

- `GET /api/v1/rewards/me`
- `GET /api/v1/rewards/leaderboard?window=&limit=`
- `POST /api/v1/admin/rewards/recompute`

## Known assumptions / limitations

See [docs/backend-assumptions.md](./docs/backend-assumptions.md).
