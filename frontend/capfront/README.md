# Capfront (Angular Web Frontend)

Admin-first Angular web client for Skopje Price Compass. This page follows the same documentation style as the repository main page and focuses on web scope, status, and interfaces.

## Documentation Scope

- Describes implemented web behavior and contracts with backend.
- Avoids environment secrets or machine-specific configuration.
- Keeps user-facing setup concise and implementation notes explicit.

## Web Goal

Deliver:

1. Public read-only catalog browsing for quick discovery
2. Full admin moderation workflow on web
3. Rewards visibility and admin operations for contributor management

Consumer-heavy shopping flows remain primarily in the mobile app.

## Current Status (At a Glance)

### Implemented

- Public catalog pages (`/products`, `/products/:id`) with search and rich product detail
- Admin auth and route guards (`/admin/login`, protected `/admin/*`)
- Admin dashboard summary and queue health views
- Moderation queue with server-driven filters, pagination metadata, AI hints, and compare previews
- Queue-level actions: approve, reject, and payload edit for pending submissions
- Submission detail page with typed editor, history, AI refresh, and evidence preview
- Rewards page with leaderboard, my stats, and recompute action
- Theme toggling and dark-mode support

### Partially Implemented / In Progress

- Visual polish continues for a few dense admin views
- End-to-end browser automation coverage is still limited

### Next Work for Capstone Polish

- Add stronger e2e coverage for moderation conflict/retry paths
- Finalize UX consistency pass across all admin states (loading/error/empty/success)
- Expand accessibility verification and keyboard-flow checks

## Architecture Overview

### Routing and Feature Areas

- Route definitions: `src/app/app.routes.ts`
- Public: `features/public/product-list`, `features/public/product-detail`
- Admin: `features/admin/admin-login`, `admin-dashboard`, `admin-submissions`, `admin-rewards`

### State and UI Stack

- Angular 20 standalone components
- Angular Material component system
- Signals for view state + reactive forms for input workflows
- HttpClient with auth interceptor + route guards

## Interface Contracts with Backend

### Public Catalog

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

Additional assumptions are documented in [docs/backend-assumptions.md](./docs/backend-assumptions.md).

## Auth and Access Behavior

- Public product routes are open.
- Admin routes require authenticated admin session.
- Unauthorized/forbidden route access redirects to `/admin/login` with reason context.
- `401` responses on protected admin API calls clear session and redirect with `reason=sessionExpired`.

## Run and Quality Checks

From `frontend/capfront`:

```bash
npm install
npm start
```

`proxy.conf.json` forwards `/api` requests to `http://localhost:8080`.

Build and test:

```bash
npm run build
npm test -- --watch=false --browsers=ChromeHeadless
```

If Chrome/Chromium is not installed, set `CHROME_BIN` to a valid executable.

## Known Risks and Gaps

- Browser test execution depends on local Chrome availability
- Moderate CSS complexity in admin submissions page exceeds current style budget threshold
- Regression risk remains highest around moderation state transitions and payload patch conflicts

## Related Documentation

- Root project overview: `../../README.md`
- Backend assumptions for web contracts: `./docs/backend-assumptions.md`
