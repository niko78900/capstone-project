# Skopje Price Compass

Skopje Price Compass is a capstone project for crowd-sourced supermarket price comparison in Skopje. The system lets shoppers browse verified product prices, compare a local item list across supermarkets, submit new product and price evidence, and route those submissions through admin moderation before they affect the catalog.

The repository contains three coordinated applications:

- `backend/supermarket-api` - Spring Boot REST API, PostgreSQL persistence, Flyway migrations, security, moderation, rewards, imports, uploads, and optional AI support.
- `frontend/capfront` - Angular web app for public catalog browsing and admin moderation/rewards workflows.
- `mobileapp/cap_app` - Flutter shopper app for authentication, catalog search, item lists, comparison, barcode-assisted flows, submissions, and submission status tracking.

## System Overview

The backend is the source of truth. Both clients use JSON REST endpoints under `/api/v1`.

```text
Flutter mobile app  --->  Spring Boot API  --->  PostgreSQL
Angular web app    --->  Spring Boot API  --->  Upload storage
                                      |
                                      +-- Optional OpenAI extraction/review support
```

Authentication is JWT-based. The backend issues bearer tokens from `/api/v1/auth/register` and `/api/v1/auth/login`. The Angular app stores the session in `localStorage`, while the Flutter app stores the token with `flutter_secure_storage`.

Uploaded images are stored under the configured uploads directory and served through `/uploads/**`. Database schema and seed data are managed through Flyway migrations in `backend/supermarket-api/src/main/resources/db/migration`.

## Implemented Features

### Backend API

- User registration and login with bcrypt password hashing and JWT sessions.
- Role-based authorization with protected admin routes.
- Public product catalog APIs with search by product name, brand, or barcode.
- Product detail APIs with category, brand, image URL, barcode, nutrition, and latest supermarket prices.
- Supermarket listing API.
- Single-supermarket cart comparison that ranks stores by cart coverage and total cost.
- Product submissions with category, barcode, supermarket, price, optional image, and optional nutrition data.
- Price submissions for existing catalog products.
- Image upload validation and persistent upload storage.
- Authenticated "my submissions" history with latest review reason.
- Admin moderation queue with status/type/search filters, pagination, and safe sorting.
- Admin submission detail, payload editing, optimistic concurrency checks, and edit audit history.
- Admin approve/reject decisions for product, price, and nutrition submission records.
- Rewards scoring, contributor stats, leaderboard windows, and admin recompute.
- Optional AI product draft extraction and moderation review hints.
- Admin CSV catalog import dry-run and commit workflow with job/row tracking.
- OpenAPI/Swagger UI and actuator health/info/metrics support.

### Angular Web App

- Public catalog route at `/products`.
- Public product detail route at `/products/:id`.
- Admin login route at `/login` with guarded admin routes.
- Admin dashboard with moderation queue counts, oldest pending item, recent pending snapshot, and top contributors.
- Admin moderation list with server-backed filters, paging, queue actions, AI hints, and current-catalog comparison previews.
- Admin submission detail with typed payload editor, evidence preview, history, AI refresh, approve, and reject actions.
- Rewards page with contributor stats, leaderboard, reward-window selection, and admin recompute.
- Auth interceptor for bearer tokens and session cleanup on protected `401` responses.
- Dark/light theme support.

### Flutter Mobile App

- Login, registration, logout, session restore, and remembered credentials.
- Protected mobile routing with a bottom navigation shell.
- Shop/home screen with search, sorting, barcode actions, and product cards.
- Product detail screen with price rows, nutrition, image support, and add-to-items action.
- Local My Items/cart persistence with add, increment, decrement, update, remove, clear, and recent item re-add.
- Cart comparison flow connected to `/api/v1/cart/compare/single-supermarket`.
- Supermarket list and supermarket-specific product browsing.
- Android barcode scanning with camera scan, image analysis, and manual code entry fallback.
- Barcode resolution to open a matching product or start a product submission for unknown codes.
- Manual product submission with image upload, barcode scan, price, and nutrition fields.
- Guided product submission flow with staged barcode/product/price/nutrition/image capture.
- Price update submission flow with scan, confirm, not-found, and submit stages.
- AI-assisted product prefill from price-tag and nutrition-label images.
- My submissions screen showing `PENDING`, `APPROVED`, and `REJECTED` statuses.
- Local notification polling for submission decision changes.
- Settings for theme preference, decision notifications, and debug error visibility.

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
|       `-- src/app/
|           |-- core/
|           |-- features/admin/
|           |-- features/public/
|           `-- shared/
|-- mobileapp/
|   `-- cap_app/
|       `-- lib/
|           |-- app/
|           |-- core/
|           |-- features/
|           `-- shared/
`-- docker-compose.yml
```

## Backend Documentation

### Main Stack

- Java 21
- Spring Boot 4
- Spring Web MVC
- Spring Security
- Spring Data JPA
- Flyway
- PostgreSQL
- JWT through `jjwt`
- Springdoc OpenAPI
- Actuator and Prometheus metrics
- H2 for tests

### Main Modules

- `api/v1/auth` - registration, login, JWT response creation.
- `api/v1/catalog` - products, product detail, supermarkets.
- `api/v1/cart` - single-supermarket cart comparison.
- `api/v1/submissions` - product/price submissions, image uploads, AI product draft endpoints, current-user submission history.
- `api/v1/moderation` - admin queue, detail, payload patching, AI refresh, approval, rejection, history.
- `api/v1/rewards` - current-user rewards, leaderboard, admin recompute.
- `api/v1/imports` - admin catalog CSV dry-run, commit, and job inspection.
- `api/v1/ai` - OpenAI-backed extraction and moderation analysis support.
- `security` - stateless JWT filtering, role rules, JSON auth/forbidden responses.
- `storage` - upload path resolution, startup validation, and storage health checks.

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

### Data Model

The backend schema includes:

- Users and roles
- Supermarkets and branches
- Categories
- Products with barcode, image URL, normalized name, normalized brand, and active flag
- Product nutrition
- Verified prices
- Submissions
- Submission reviews
- Submission edits
- Submission AI analysis records
- Contributor stats
- Contributor score events
- Import jobs and import job rows

Flyway migrations:

- `V1__create_core_schema.sql`
- `V2__seed_catalog_and_prices.sql`
- `V3__advanced_backend_features.sql`
- `V4__seed_additional_supermarkets.sql`
- `V5__seed_zur_reptil_supermarkets.sql`

### Moderation Behavior

Submissions are created with `PENDING` status. Admin users can inspect the submission payload, compare it with current catalog data, patch pending payloads, refresh AI review hints, and approve or reject the submission.

Payload patching supports optimistic concurrency through `expectedUpdatedAt`. Each edit is persisted in `submission_edits` with before/after payload data, an optional reason, changed field count, and admin user reference.

Approval effects:

- Product submissions create or update product data, optionally update nutrition, and create a verified price.
- Price submissions create a verified price for an existing product.
- Nutrition submission records update product nutrition.
- Every decision creates review history and updates contributor rewards.

### Rewards

Reward events are recorded from moderation decisions:

- Approved product submission: `+10`
- Approved price submission: `+6`
- Approved nutrition submission: `+5`
- Rejected submission: `-2`

Contributor stats and leaderboard data are maintained incrementally. Admin recompute can rebuild score events and stats from review history.

### Optional AI Configuration

AI support is optional. Core submission and moderation flows continue without an OpenAI API key.

Environment variables:

- `APP_OPENAI_API_KEY`
- `APP_OPENAI_MODEL`
- `APP_OPENAI_CHAT_COMPLETIONS_URL`
- `APP_OPENAI_TIMEOUT_MS`
- `APP_OPENAI_IMAGE_DETAIL`
- `APP_AI_PROMPT_VERSION`

Configured AI support is used for product draft extraction from images and moderation review summaries.

## Web App Documentation

### Main Stack

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

### Backend Integration

The web app uses relative `/api/v1` and `/uploads` URLs. During local development, `frontend/capfront/proxy.conf.json` forwards those paths to `http://localhost:8080`.

Core services:

- `CatalogService` - products, product detail, supermarkets.
- `AuthService` and `AuthSessionService` - login and browser session persistence.
- `ModerationService` - admin queue, detail, history, payload patching, AI refresh, approve, reject.
- `RewardsService` - current-user stats, leaderboard, admin recompute.

## Mobile App Documentation

### Main Stack

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

### Backend Integration

The API base URL comes from the `API_BASE_URL` Dart define. If it is not supplied, the app defaults to `http://10.0.2.2:8080`, which targets the host machine from an Android emulator.

The mobile network layer attaches bearer tokens automatically, maps backend error payloads into app exceptions, supports multipart uploads, and retries once with a freshly read auth token after a `401`.

## End-to-End Workflows

### Browse and Compare

1. A user opens the web catalog or mobile shop.
2. The client loads products from `GET /api/v1/products`.
3. Product details come from `GET /api/v1/products/{id}`.
4. The mobile user adds products to a local item list.
5. The mobile app posts the cart to `POST /api/v1/cart/compare/single-supermarket`.
6. The backend ranks supermarkets and returns coverage, missing items, line items, diagnostics, and the cheapest full-coverage option when available.

### Crowd Submission

1. A mobile user submits a product or price update.
2. The backend validates references, duplicate barcode/name-brand rules, branch ownership, image safety, and payload shape.
3. The backend stores a pending submission.
4. Optional AI analysis creates review hints.
5. The user can review submission status from `GET /api/v1/submissions/me`.

### Admin Moderation

1. An admin signs in through the Angular app.
2. The admin opens the moderation queue.
3. The web app loads filtered/paged submissions from `GET /api/v1/admin/submissions`.
4. The admin reviews submitted values, evidence, current catalog context, history, and AI hints.
5. The admin can patch the payload before decision.
6. Approval applies catalog changes and records reward points.
7. Rejection records review history and applies the rejection score.

## Local Development

### Docker Compose

From the repository root:

```bash
docker compose up --build
```

This starts PostgreSQL and the backend API. The API is exposed on `http://localhost:8080`; actuator management endpoints are exposed on `http://localhost:18081`.

### Backend

From `backend/supermarket-api`:

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

On Windows PowerShell:

```powershell
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

Default profile variables:

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`
- `APP_JWT_SECRET`
- `APP_ADMIN_BOOTSTRAP_TOKEN`
- `APP_AUTH_ALLOW_ADMIN_BOOTSTRAP_REGISTRATION`
- `APP_UPLOADS_DIR`
- `MANAGEMENT_PORT`

### Angular Web

From `frontend/capfront`:

```bash
npm install
npm start
```

Angular serves the app locally and uses `proxy.conf.json` for backend API calls.

### Flutter Mobile

From `mobileapp/cap_app`:

```bash
flutter pub get
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080
```

For a physical Android device, use the host machine LAN address instead of `10.0.2.2`.

## Quality Checks

Backend:

```bash
cd backend/supermarket-api
./mvnw test
```

Frontend:

```bash
cd frontend/capfront
npm test -- --watch=false --browsers=ChromeHeadless
```

Mobile:

```bash
cd mobileapp/cap_app
flutter analyze
flutter test
```

Automated tests are present for backend unit/integration behavior, Angular services/pages/guards/interceptors, and Flutter models/providers/widgets/workflows.

## Deployment Shape

`docker-compose.yml` defines:

- `postgres` using `postgres:16-alpine`
- `api` built from `backend/supermarket-api/Dockerfile`
- Persistent PostgreSQL data volume
- Persistent API upload volume
- API port `8080`
- Local management port mapping `127.0.0.1:18081 -> 8081`
- Health checks for PostgreSQL and API readiness

The backend also includes upload storage startup validation and an upload storage health indicator.

## Related Documentation

- Backend README: `backend/supermarket-api/README.md`
- Angular README: `frontend/capfront/README.md`
- Mobile README: `mobileapp/cap_app/README.md`
- Frontend backend assumptions: `frontend/capfront/docs/backend-assumptions.md`
