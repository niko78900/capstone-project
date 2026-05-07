# Skopje Price Compass Documentation

This document is the detailed technical reference for Skopje Price Compass. The root `README.md` is intentionally concise; this file contains the broader architecture notes, contracts, workflows, setup details, and quality status.

## Project Overview

Skopje Price Compass is a mobile-first supermarket price comparison system for Skopje. It combines a verified product catalog, supermarket-specific prices, crowd-sourced product and price submissions, admin moderation, contributor rewards, and cart comparison.

The system is built around a single backend API. The Angular web app is used for public browsing and administration. The Flutter mobile app is the primary shopper-facing client.

High-level goals:

- Let users browse products and verified supermarket prices.
- Let users inspect price changes over time by market.
- Let users build a local shopping list and compare the cheapest single supermarket for that list.
- Let users submit missing products, price updates, images, and nutrition details.
- Let admins review, edit, approve, or reject submissions before catalog data changes.
- Reward contributors for approved submissions.
- Support optional AI-assisted extraction and review without making AI required for core flows.

## Repository Applications

| Area | Path | Responsibility |
| --- | --- | --- |
| Backend API | `backend/supermarket-api` | Source of truth for users, catalog, prices, submissions, moderation, rewards, imports, uploads, and AI integration. |
| Angular web app | `frontend/capfront` | Public catalog pages and admin workflows. |
| Flutter mobile app | `mobileapp/cap_app` | Shopper-first mobile experience, cart comparison, barcode flows, submissions, and status tracking. |

## System Architecture

```text
Flutter mobile app  --->  Spring Boot API  --->  PostgreSQL
Angular web app    --->  Spring Boot API  --->  Upload storage
                                      |
                                      +-- Optional OpenAI extraction/review support
```

The backend exposes JSON REST endpoints under `/api/v1`. Both clients treat the backend as the source of truth for catalog and moderation data. Uploaded images are stored on disk through the configured upload directory and are served under `/uploads/**`.

Authentication is JWT-based:

- Users register and log in through `/api/v1/auth/register` and `/api/v1/auth/login`.
- The backend returns a bearer token and user metadata.
- Angular stores the admin session in browser storage.
- Flutter stores the auth token through `flutter_secure_storage`.
- Flutter also supports remembered credentials on the device when the user opts in.

## Backend

### Stack

- Java 21
- Spring Boot 4
- Spring Web MVC
- Spring Security
- Spring Data JPA
- Flyway
- PostgreSQL
- H2 for tests
- JWT with `jjwt`
- Springdoc OpenAPI
- Actuator and Prometheus metrics

### Main Modules

- `api/v1/auth`: registration, login, JWT response creation.
- `api/v1/catalog`: products, product detail, price history, supermarkets.
- `api/v1/cart`: single-supermarket cart comparison.
- `api/v1/submissions`: product submissions, price submissions, image uploads, AI draft endpoints, current-user submission history.
- `api/v1/moderation`: admin queue, detail, payload patching, AI review, approval, rejection, history.
- `api/v1/rewards`: current-user rewards, leaderboard, admin recompute.
- `api/v1/imports`: admin CSV catalog import dry-run, commit, and job inspection.
- `api/v1/ai`: OpenAI-backed extraction and moderation analysis support.
- `domain`: JPA entities and repository interfaces.
- `security`: JWT filtering, role rules, JSON auth/forbidden responses.
- `storage`: upload path resolution, startup validation, and upload health checks.

### Data Model

The database schema includes:

- Users and roles
- Supermarkets
- Branches
- Categories
- Products
- Product nutrition
- Verified prices
- Submissions
- Submission reviews
- Submission edits
- Submission AI analysis records
- Contributor stats
- Contributor score events
- Import jobs
- Import job rows

Products include barcode, image URL, normalized name, normalized brand, category, and active status. Verified prices are stored historically, so product detail can return both the latest market price and price history over time.

### Flyway Migrations

- `V1__create_core_schema.sql`: users, supermarkets, branches, categories, products, nutrition, submissions, reviews, verified prices.
- `V2__seed_catalog_and_prices.sql`: initial categories, supermarkets, branches, demo catalog, nutrition, and verified prices.
- `V3__advanced_backend_features.sql`: submission edits, AI analysis, rewards, score events, import jobs.
- `V4__seed_additional_supermarkets.sql`: Kipper and Kit-go.
- `V5__seed_zur_reptil_supermarkets.sql`: Zur and Reptil.
- `V6__remove_example_seed_products.sql`: removes early example/demo products while keeping the real structure.

### API Summary

Public endpoints:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/products`
- `GET /api/v1/products/{id}`
- `GET /api/v1/supermarkets`
- `GET /uploads/**`
- `GET /swagger-ui/**`
- `GET /v3/api-docs/**`
- `GET /actuator/health`
- `GET /actuator/info`

Authenticated user endpoints:

- `POST /api/v1/cart/compare/single-supermarket`
- `POST /api/v1/submissions/product`
- `POST /api/v1/submissions/price`
- `POST /api/v1/submissions/product/ai-draft`
- `POST /api/v1/submissions/product/ai-draft-upload`
- `POST /api/v1/submissions/images`
- `GET /api/v1/submissions/me`
- `GET /api/v1/rewards/me`
- `GET /api/v1/rewards/leaderboard`

Admin endpoints:

- `GET /api/v1/admin/submissions`
- `GET /api/v1/admin/submissions/{id}`
- `PATCH /api/v1/admin/submissions/{id}/payload`
- `GET /api/v1/admin/submissions/{id}/history`
- `POST /api/v1/admin/submissions/{id}/ai-review`
- `POST /api/v1/admin/submissions/{id}/approve`
- `POST /api/v1/admin/submissions/{id}/reject`
- `POST /api/v1/admin/rewards/recompute`
- `POST /api/v1/admin/imports/catalog/dry-run`
- `POST /api/v1/admin/imports/catalog/commit`
- `GET /api/v1/admin/imports/{jobId}`
- `GET /actuator/metrics`
- `GET /actuator/prometheus`

### Catalog Behavior

`GET /api/v1/products` supports product listing and search. Product matching includes product name, brand, and barcode. Product summaries expose the best verified price where available.

`GET /api/v1/products/{id}` returns a richer detail payload:

- Product identity: id, name, brand, barcode, category, image URL
- Nutrition values when available
- `prices`: latest verified price per supermarket
- `priceHistory`: all verified price rows for that product, sorted by `observedAt` ascending

The clients use `prices` for current market offers and `priceHistory` for charting over time.

### Cart Comparison

The mobile app sends the local item list to:

```text
POST /api/v1/cart/compare/single-supermarket
```

The backend:

1. Aggregates duplicate product quantities.
2. Validates product IDs.
3. Looks up the latest verified price per product per supermarket.
4. Evaluates each supermarket for item coverage and total cost.
5. Sorts full-coverage supermarkets ahead of partial coverage.
6. Returns ranked supermarket results, missing items, line totals, diagnostics, and the cheapest full-coverage option when one exists.

This intentionally answers the capstone question: which single supermarket is cheapest for the selected cart.

### Submissions

Users can submit:

- New product submissions
- Price update submissions
- Image evidence uploads
- Product AI draft requests from image input

Product submissions can include:

- Product name
- Brand
- Barcode
- Category
- Supermarket
- Branch
- Price
- Optional image URL
- Optional nutrition values

Price submissions target an existing product and add a pending verified-price candidate. They can include a selected supermarket, branch, price, image evidence, and observation date.

Submissions start as `PENDING`. They do not alter verified catalog data until approved by an admin.

### Moderation

Admins can:

- List pending/approved/rejected submissions with filters and pagination.
- View submission detail.
- Inspect submitted payloads and evidence.
- Compare submitted product data against current catalog data.
- Patch pending payloads before decision.
- Refresh AI review hints.
- Approve or reject submissions.
- Review edit and decision history.

Payload patching supports optimistic concurrency through `expectedUpdatedAt`. If another moderator updates the submission first, the backend returns `409`, and Angular reloads the latest submission data.

Approval effects:

- Product submissions create or update product data, optionally update nutrition, and create a verified price.
- Price submissions create a verified price row for an existing product.
- Nutrition submissions update product nutrition.
- Every decision creates review history and updates contributor rewards.

### Rewards

Reward events are recorded from moderation decisions:

- Approved product submission: `+10`
- Approved price submission: `+6`
- Approved nutrition submission: `+5`
- Rejected submission: `-2`

The backend maintains contributor stats and score events. Leaderboards support:

- All time
- Last 30 days

Admins can recompute rewards from review history.

### AI Support

AI support is optional. If no OpenAI configuration is present, the core submission and moderation workflows still work.

Environment variables:

- `APP_OPENAI_API_KEY`
- `APP_OPENAI_MODEL`
- `APP_OPENAI_CHAT_COMPLETIONS_URL`
- `APP_OPENAI_TIMEOUT_MS`
- `APP_OPENAI_IMAGE_DETAIL`
- `APP_AI_PROMPT_VERSION`

Configured AI support is used for:

- Product draft extraction from submitted images
- Moderation review hints
- Confidence, warning, and flag summaries

The mobile app no longer relies on AI for barcode extraction. Barcode images go through barcode scanning instead.

## Angular Web App

### Stack

- Angular 20 standalone components
- Angular Material
- Angular Router
- Angular HttpClient
- Signals and computed state
- Reactive forms
- RxJS
- Karma/Jasmine specs

### Routes

- `/` redirects to `/products`
- `/products`
- `/products/:id`
- `/login`
- `/admin/login` redirects to `/login`
- `/rewards`
- `/admin`
- `/admin/submissions`
- `/admin/submissions/:id`
- `/admin/rewards` redirects to `/rewards`

### Public Catalog

The public web catalog lets users:

- Search products
- Browse product cards
- See best verified market price
- See market logos
- Open product detail
- View nutrition
- View verified supermarket prices
- View price history by market

The product detail price-history chart is native SVG. It groups points by supermarket and draws one line per market using stable market colors.

### Admin Areas

The admin web app includes:

- Login
- Dashboard
- Moderation queue
- Submission detail
- Payload editor
- Evidence preview
- AI review refresh
- Approve/reject actions
- Rewards page
- Leaderboard window selector
- Admin recompute

### Frontend Contracts

The Angular app relies on these backend contracts:

- `GET /api/v1/admin/submissions` returns a paged envelope.
- Angular consumes `items`, `totalElements`, `page`, `size`, and `totalPages`.
- Payload patching is supported only for `PENDING` submissions.
- Angular sends `expectedUpdatedAt` for optimistic concurrency.
- Backend `409` means stale moderator data and triggers reload behavior.
- Backend `fieldErrors` are shown in edit flows.
- Evidence preview uses `payload.imageUrl` when available.
- Public catalog search uses `q`.
- Product detail uses `prices` for latest prices and `priceHistory` for charting.

### Market Logos

Market logos are stored under:

```text
frontend/capfront/public/market-logos/
```

Angular uses a reusable `MarketLogoComponent` with normalized supermarket-name lookup. Known markets render image assets; unknown names render a storefront/initials fallback.

## Flutter Mobile App

### Stack

- Flutter
- Material 3
- Riverpod
- `go_router`
- Dio
- `flutter_secure_storage`
- `shared_preferences`
- `image_picker`
- `mobile_scanner`
- `flutter_local_notifications`

### Android Identity

- App name: `Skopje Price Compass`
- Android namespace/application id: `com.niko.skopjepricecompass`
- Release signing is wired through an untracked local `android/key.properties` file.

### Routes

- `/login`
- `/register`
- `/shop`
- `/items`
- `/supermarkets`
- `/supermarkets/:id/products`
- `/account`
- `/product/:id`
- `/compare/result`
- `/submit/product`
- `/submit/product/guided`
- `/submit/price`
- `/submissions`
- `/settings`

### Main Mobile Flows

The mobile app supports:

- Login and registration
- Session restore
- Remembered credentials
- Logout
- Product browse/search
- Product detail
- Price-history chart
- Market logos
- Local My Items/cart
- Cart comparison
- Supermarket listing
- Supermarket-specific products
- Barcode scan and manual barcode entry fallback
- Manual product submission
- Guided product submission
- Price update submission
- AI-assisted draft merge
- My submissions status tracking
- Local notification polling
- Theme/settings controls
- Android back-button and gesture exit confirmation on root tabs

### Market Logos

Market logos are stored under:

```text
mobileapp/cap_app/assets/market_logos/
```

Flutter uses a shared `MarketLogo` widget. Known markets render local image assets; unknown names render a storefront/initials fallback.

### API Base URL

The API base URL comes from the `API_BASE_URL` Dart define:

```powershell
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080
```

If omitted, the app defaults to `http://10.0.2.2:8080`, which targets the host machine from an Android emulator.

For physical devices, use the host computer LAN IP instead.

## End-To-End Workflows

### Browse And Compare

1. User opens the mobile shop or web catalog.
2. Client loads products from `GET /api/v1/products`.
3. Product detail loads from `GET /api/v1/products/{id}`.
4. Mobile user adds products to My Items.
5. Mobile posts the item list to `POST /api/v1/cart/compare/single-supermarket`.
6. Backend ranks supermarkets by coverage and total cost.
7. Mobile displays the cheapest eligible option and ranked alternatives.

### Submit Product Or Price

1. User starts product or price submission from mobile.
2. User scans barcode, enters product/price details, and optionally uploads evidence.
3. Backend validates references, duplicate barcode/name-brand rules, branch ownership, image safety, and payload shape.
4. Backend stores a pending submission.
5. Optional AI analysis creates draft or review hints.
6. User can track submission status from My Submissions.

### Admin Review

1. Admin signs in through Angular.
2. Admin opens the moderation queue.
3. Angular loads filtered/paged submissions.
4. Admin reviews submitted payload, evidence, current catalog context, history, and AI hints.
5. Admin can patch pending payloads.
6. Admin approves or rejects.
7. Backend applies catalog changes if approved.
8. Backend records review history and reward events.

## Local Development

### Docker Compose

From the repository root:

```bash
docker compose up --build
```

This starts PostgreSQL and the backend API. The API is exposed on:

```text
http://localhost:8080
```

Actuator management endpoints are exposed on:

```text
http://localhost:18081
```

### Backend Direct Run

From `backend/supermarket-api`:

```powershell
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

Common variables:

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`
- `APP_JWT_SECRET`
- `APP_ADMIN_BOOTSTRAP_TOKEN`
- `APP_AUTH_ALLOW_ADMIN_BOOTSTRAP_REGISTRATION`
- `APP_UPLOADS_DIR`
- `MANAGEMENT_PORT`

### Angular Run

From `frontend/capfront`:

```powershell
npm install
npm start
```

Angular serves the app locally and uses `proxy.conf.json` to forward `/api` and `/uploads` to the backend.

### Flutter Run

From `mobileapp/cap_app`:

```powershell
flutter pub get
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080
```

## Quality Checks

Backend:

```powershell
cd backend/supermarket-api
.\mvnw.cmd test
```

Angular:

```powershell
cd frontend/capfront
npm run build
$env:CHROME_BIN="C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"
npm test -- --watch=false --browsers=ChromeHeadless
```

Any Chrome/Chromium browser should work for Angular tests as long as `CHROME_BIN` points to the executable.

Flutter:

```powershell
cd mobileapp/cap_app
flutter analyze
flutter test
flutter build apk --debug
```

Current verified status:

- Backend tests: 45 passing
- Angular specs: 37 passing
- Flutter tests: 31 passing
- Flutter analyze: clean
- Angular build: passing

## Deployment Shape

`docker-compose.yml` defines:

- `postgres` using `postgres:16-alpine`
- `api` built from `backend/supermarket-api/Dockerfile`
- Persistent PostgreSQL data volume
- Persistent API upload volume
- API port `8080`
- Local management port mapping `127.0.0.1:18081 -> 8081`
- Health checks for PostgreSQL and API readiness

The backend also includes:

- Upload storage startup validation
- Upload storage health indicator
- Actuator health/info endpoints
- Admin-authenticated metrics/prometheus endpoints

## Repository Structure

```text
.
|-- backend/
|   `-- supermarket-api/
|       |-- src/main/java/com/niko/capstone/supermarket_api/
|       |   |-- api/v1/
|       |   |-- domain/
|       |   |-- security/
|       |   `-- storage/
|       `-- src/main/resources/db/migration/
|-- frontend/
|   `-- capfront/
|       |-- public/market-logos/
|       `-- src/app/
|           |-- core/
|           |-- features/admin/
|           |-- features/public/
|           `-- shared/
|-- mobileapp/
|   `-- cap_app/
|       |-- assets/market_logos/
|       `-- lib/
|           |-- app/
|           |-- core/
|           |-- features/
|           `-- shared/
|-- docker-compose.yml
|-- README.md
`-- documentation.md
```
