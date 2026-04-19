# Skopje Price Compass

Crowd-sourced supermarket price comparison platform for Skopje, built as a multi-app capstone project.

This repository contains three coordinated application areas:

- `backend/supermarket-api` (Spring Boot API + PostgreSQL/Flyway)
- `frontend/capfront` (Angular web app: public catalog + admin moderation)
- `mobileapp/cap_app` (Flutter mobile app: shopping-first end-user client)

## Documentation Scope

This homepage intentionally focuses on project scope, implemented functionality, current gaps, and next work.

- Setup and environment bootstrap instructions are intentionally excluded from this public README.
- Internal setup notes, secrets, and environment-specific connection details should remain outside public docs.

## Project Goal

Skopje Price Compass helps users compare verified product prices across supermarkets, build an item list, and submit crowd-sourced updates that pass through moderation before publication.

The capstone target is a complete workflow:

1. Shopper browses/searches products
2. Shopper reviews product details (including nutrition where available)
3. Shopper adds items and compares totals across supermarkets
4. Shopper submits new product/price/evidence updates
5. Admin moderates submissions (approve/reject/edit)
6. Approved updates improve catalog quality and price freshness

## Current Repository Status (At a Glance)

### Implemented

- Multi-component architecture is present and integrated (backend + web + mobile).
- JWT auth flows are implemented across clients.
- Product catalog browsing and detail retrieval are implemented.
- Cart comparison for cheapest eligible single supermarket is implemented.
- Crowd submissions (product + price + image upload) are implemented.
- Admin moderation queue/detail flows are implemented on web.
- Rewards/leaderboard backend and web pages are implemented.
- AI-assisted draft/review backend support exists with graceful fallback behavior.

### Partially Implemented / In Progress

- Mobile barcode support is currently a UI entry point with placeholder scan behavior.
- Mobile shell refactor is active; core shopping-first nav exists, but UX polish remains.
- End-to-end cross-app testing exists but is not yet comprehensive for all critical flows.

### Still Needed for “Finished” Capstone Polish

- Full scanner package integration and barcode-driven product lookup flow in mobile.
- Broader automated test coverage (especially e2e workflow and negative-path integration cases).
- Production-grade deployment hardening/observability documentation.
- Final presentation/demo artifacts tied to proposal acceptance criteria.

## Architecture Overview

### 1) Backend API (`backend/supermarket-api`)

Primary responsibilities:

- Authentication and role-based authorization
- Catalog read APIs
- Cart comparison computation
- Submission intake (product/price/image)
- Moderation queue and decisions
- Rewards and leaderboard
- AI-assisted extraction/review support
- Admin CSV import jobs

Evidence in code:

- Controllers: `api/v1/auth`, `api/v1/catalog`, `api/v1/cart`, `api/v1/submissions`, `api/v1/moderation`, `api/v1/rewards`, `api/v1/imports`
- Security/JWT: `security/SecurityConfig.java`, `security/JwtAuthenticationFilter.java`, `security/JwtService.java`
- Core services: `SubmissionService.java`, `CartComparisonService.java`, `ModerationService.java`, `RewardsService.java`, `AiAnalysisService.java`
- Flyway migrations: `src/main/resources/db/migration/V1__create_core_schema.sql`, `V2__seed_catalog_and_prices.sql`, `V3__advanced_backend_features.sql`

Current backend highlights:

- Public catalog endpoints: `/api/v1/products`, `/api/v1/products/{id}`, `/api/v1/supermarkets`
- Auth endpoints: `/api/v1/auth/register`, `/api/v1/auth/login`
- Cart compare endpoint: `/api/v1/cart/compare/single-supermarket`
- Submission endpoints: `/api/v1/submissions/product`, `/api/v1/submissions/price`, `/api/v1/submissions/images`, `/api/v1/submissions/me`
- Admin moderation/rewards/import endpoints are available under `/api/v1/admin/*`

### 2) Angular Web App (`frontend/capfront`)

Primary responsibilities:

- Public read-only catalog browsing
- Admin moderation queue/detail/review actions
- Rewards dashboard access for admin workflows

Evidence in code:

- Route map: `frontend/capfront/src/app/app.routes.ts`
- Public pages: `features/public/product-list`, `features/public/product-detail`
- Admin pages: `features/admin/admin-login`, `admin-dashboard`, `admin-submissions`, `admin-rewards`
- Services: `core/services/catalog.service.ts`, `moderation.service.ts`, `auth.service.ts`, `rewards.service.ts`
- Theme support: `core/services/theme.service.ts`

Current web highlights:

- Public catalog and product details are exposed without login
- Admin-only routes are guarded
- Moderation list/detail supports decisions and payload editing workflow
- Dark/light theme toggling exists

### 3) Flutter Mobile App (`mobileapp/cap_app`)

Primary responsibilities:

- Main end-user shopping experience
- Search and browse product catalog
- Product detail with price + nutrition context
- Item list/cart comparison workflow
- Crowd submission entry points

Evidence in code:

- Routing shell: `lib/app/app_router.dart`, `lib/app/mobile_shell.dart`
- Shop/home: `lib/features/catalog/presentation/home_screen.dart`
- Product detail: `lib/features/catalog/presentation/product_detail_screen.dart`
- My Items and cart: `lib/features/cart/presentation/my_items_screen.dart`, `cart_screen.dart`
- Supermarkets tab: `lib/features/catalog/presentation/supermarkets_screen.dart`
- Account tab: `lib/features/account/presentation/account_screen.dart`
- Submission screens/repo: `lib/features/submissions/presentation/*`, `lib/features/submissions/data/submission_repository.dart`

Current mobile highlights:

- Bottom-navigation-first shell is present (`Shop | My Items | Add | Supermarkets | Account`)
- Search-first shop header and barcode entry point are present
- My Items supports re-adding recently used items
- Cart compare flow remains available and connected to backend compare endpoint
- Submission routes are integrated from both Account and center Add action

## Data Model Coverage (Backend)

Implemented entities/tables include:

- Users and roles
- Supermarkets and branches
- Categories
- Products with barcode and image URL
- Product nutrition
- Submissions and moderation reviews
- Verified prices
- Submission edits (audit trail)
- AI analysis records
- Contributor stats and score events
- Import jobs and import rows

Evidence:

- Schema migration: `V1__create_core_schema.sql`
- Advanced workflow tables: `V3__advanced_backend_features.sql`
- Seed/demo data: `V2__seed_catalog_and_prices.sql`

## End-to-End Workflow Coverage

### Implemented End-to-End Paths

- Auth: register/login + token-backed protected routes
- Catalog: list/search -> detail -> add item
- Comparison: item list -> single-supermarket compare results
- Submissions: product/price submission + optional image upload
- Moderation: admin queue -> inspect -> approve/reject
- Rewards: score updates and leaderboard access

### Known Gaps / Risks

- Barcode scanner hardware integration in mobile is not fully implemented yet.
- Some admin and user UX areas need final visual/passive-state polish.
- Cross-app regression protection relies on limited test coverage and manual verification.

## Testing and Quality Snapshot

Current automated test evidence in repository:

- Backend tests (unit + integration): `backend/supermarket-api/src/test/java/...`
- Frontend tests (Angular specs): `frontend/capfront/src/app/**/*.spec.ts`
- Mobile tests (Flutter widget/unit): `mobileapp/cap_app/test/**`

What is still needed:

- Expanded e2e scenario coverage spanning mobile submission -> backend moderation -> frontend/admin verification
- More negative/edge-case tests around moderation conflicts and malformed payloads
- Stronger CI-level quality gates for all three app areas

## What Is Done vs What Needs To Be Done

### Done

- Core architecture and communication paths are in place.
- Core capstone domain workflows are implemented in code.
- Moderation and rewards logic exist beyond basic CRUD.
- Seed data supports realistic demo browsing and comparison.

### Needs To Be Done

- Complete scanner implementation in mobile (replace placeholder behavior).
- Expand test depth and cross-app workflow validation.
- Improve consistency and polish in UX details across light/dark themes.
- Finalize capstone-facing narrative assets (workflow evidence, demo script, acceptance checklist).
- Prepare production-hardening backlog (error budgets, observability, security review, release checklist).

## Proposed Remaining Work Plan

1. Stabilize mobile UX shell and scanner behavior for shopping-first flow completion.
2. Close all known UI theme/contrast issues and verify accessibility pass.
3. Add missing e2e tests for submission/moderation/cart-compare paths.
4. Tighten backend validation and failure-mode consistency where gaps are found.
5. Validate proposal rubric item-by-item with evidence links for final defense.
6. Build concise demo script mapped to capstone requirements.

## Public Repository Safety Notes

- Do not commit credentials, tokens, local environment files, or private setup notes.
- Do not commit database connection secrets or private infrastructure details.
- Keep sensitive local helper files excluded from version control.

## Repository Navigation

- Backend API: `backend/supermarket-api`
- Angular Web: `frontend/capfront`
- Flutter Mobile: `mobileapp/cap_app`

For detailed component-level notes, see each component folder’s local docs and source tree.
