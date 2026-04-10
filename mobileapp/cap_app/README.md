# Capstone Mobile App

Android-first Flutter end-user MVP for supermarket price comparison and submissions.

## Stack

- Flutter + Material 3
- Riverpod (state management)
- go_router (navigation)
- Dio (HTTP)
- flutter_secure_storage (JWT token storage)
- shared_preferences (local cart persistence)

## Run

Use backend URL through `API_BASE_URL`:

```bash
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080
```

For a physical Android device, replace `10.0.2.2` with your machine LAN IP.

## Implemented MVP Flows

- Register/login with JWT session restore
- Product browse and search
- Product detail with nutrition and per-supermarket prices
- Local cart add/edit/remove persistence
- Single-supermarket cart comparison with full/partial coverage diagnostics
- Product and price submission forms
- My submissions list with status chips (`PENDING`, `APPROVED`, `REJECTED`)

## Quality Checks

```bash
flutter analyze
flutter test
```
