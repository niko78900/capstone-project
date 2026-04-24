# Capstone Mobile App

Flutter mobile client for the end-user shopping workflow in Skopje Price Compass. This page follows the same documentation style as the repository main page.

## Documentation Scope

- Documents mobile responsibilities, implemented behavior, and quality status.
- Excludes secrets and environment-specific credentials.
- Focuses on Android-first behavior for capstone delivery.

## Mobile Goal

Provide a shopper-first experience:

1. Authenticate and restore session
2. Browse/search products quickly
3. Build personal item list and compare totals
4. Submit product/price updates from the field
5. Track personal submission status

## Current Status (At a Glance)

### Implemented

- JWT login/register and session restore
- Bottom navigation shell for core user flows
- Product browse, search, and detail screens
- Local My Items/cart persistence with add/remove/edit behavior
- Single-supermarket comparison flow with diagnostics
- Product and price submission forms with optional evidence upload integration
- My submissions tracking with status chips (`PENDING`, `APPROVED`, `REJECTED`)
- Back-button/gesture exit confirmation on root tabs

### Partially Implemented / In Progress

- Barcode scan flow exists with scanner tooling entry points and fallback UX, but still needs final validation on broader device matrix
- UX polish pass continues across edge states in some screens

### Next Work for Capstone Polish

- Final scanner behavior hardening and device-level reliability checks
- Expanded widget/integration test coverage for multi-step submission and compare flows
- Final UI consistency pass for all empty/error/retry states

## Architecture Overview

### Core Stack

- Flutter + Material 3
- Riverpod for state management
- `go_router` for app routing/shell navigation
- Dio for HTTP
- `flutter_secure_storage` for auth token/remembered credentials
- `shared_preferences` for local persistence

### Key Areas in Code

- Routing and shell: `lib/app/app_router.dart`, `lib/app/mobile_shell.dart`
- Catalog/shop: `lib/features/catalog/presentation/*`
- Item list/cart: `lib/features/cart/presentation/*`
- Auth: `lib/features/auth/*`
- Submissions: `lib/features/submissions/*`
- Account/settings: `lib/features/account/*`, `lib/features/settings/*`

## Backend Interface Summary

Mobile client consumes backend APIs for:

- Auth (`/api/v1/auth/*`)
- Catalog (`/api/v1/products`, `/api/v1/products/{id}`, `/api/v1/supermarkets`)
- Comparison (`/api/v1/cart/compare/single-supermarket`)
- Submissions (`/api/v1/submissions/*`)

API response contracts are shared with backend and should stay backward-compatible for mobile release stability.

## Run and Quality Checks

Set backend URL with `API_BASE_URL`:

```bash
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080
```

For physical Android device testing, replace `10.0.2.2` with host LAN IP.

Quality checks:

```bash
flutter analyze
flutter test
```

## Known Risks and Gaps

- Scanner behavior still has the highest device-variance risk
- Full cross-app e2e coverage (mobile submit -> web moderation -> mobile visibility) is not fully automated
- Manual regression checks remain important before demos/releases

## Related Documentation

- Root project overview: `../../README.md`
