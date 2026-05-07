# Skopje Price Compass

Skopje Price Compass is a capstone project for crowd-sourced supermarket price comparison in Skopje. The app helps shoppers browse verified grocery prices, inspect product price history, build a shopping list, compare the cheapest single supermarket for that list, and submit product or price updates for admin review.

## Applications

| App | Path | Description |
| --- | --- | --- |
| Backend API | `backend/supermarket-api` | Spring Boot REST API with PostgreSQL, Flyway, JWT auth, catalog, submissions, moderation, rewards, uploads, imports, and optional AI support. |
| Web frontend | `frontend/capfront` | Angular public catalog and admin web dashboard for moderation, submission review, rewards, and product details. |
| Mobile app | `mobileapp/cap_app` | Flutter shopper app for browsing products, cart comparison, barcode-assisted flows, submissions, and submission status tracking. |

## Main Features

- Public product catalog with search, nutrition, verified market prices, market logos, and price-history charts.
- Mobile shopping list with single-supermarket cart comparison.
- Product and price submissions from the mobile app.
- Guided product submission flow with barcode scanning and optional image evidence.
- Admin moderation queue with edit, approve, reject, evidence preview, history, and AI review hints.
- Contributor rewards, score tracking, leaderboard windows, and admin recompute.
- CSV catalog import dry-run and commit workflow.
- Local upload storage and optional OpenAI-assisted product extraction/review.

## Tech Stack

- Backend: Java 21, Spring Boot 4, Spring Security, Spring Data JPA, Flyway, PostgreSQL, H2 tests, JWT, Springdoc OpenAPI, Actuator.
- Web: Angular 20, Angular Material, Angular Router, HttpClient, signals, reactive forms, RxJS, Karma/Jasmine.
- Mobile: Flutter, Material 3, Riverpod, `go_router`, Dio, `flutter_secure_storage`, `shared_preferences`, `image_picker`, `mobile_scanner`, local notifications.

## Repository Structure

```text
.
|-- backend/
|   `-- supermarket-api/
|-- frontend/
|   `-- capfront/
|-- mobileapp/
|   `-- cap_app/
|-- docker-compose.yml
|-- README.md
`-- documentation.md
```

## Local Setup

### Backend And Database

From the repository root:

```bash
docker compose up --build
```

This starts PostgreSQL and the backend API. The API is available at `http://localhost:8080`.

To run the backend directly:

```powershell
cd backend/supermarket-api
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

### Angular Web

```powershell
cd frontend/capfront
npm install
npm start
```

The Angular app uses `proxy.conf.json` to forward `/api` and `/uploads` to the backend.

### Flutter Mobile

```powershell
cd mobileapp/cap_app
flutter pub get
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080
```

Use the host machine LAN address instead of `10.0.2.2` when running on a physical Android device.

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

Flutter:

```powershell
cd mobileapp/cap_app
flutter analyze
flutter test
flutter build apk --debug
```

## Documentation

See [documentation.md](documentation.md) for the full architecture, API summary, workflows, data model, client routes, configuration notes, and testing details.
