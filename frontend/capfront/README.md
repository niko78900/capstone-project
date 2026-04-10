# Capfront (Angular Web MVP)

Angular frontend for the capstone web scope:
- Public read-only product browsing (`/products`, `/products/:id`)
- Admin moderation dashboard (`/admin/login`, `/admin/submissions`)

## Tech Stack

- Angular 20 (standalone APIs)
- Angular Material
- HttpClient with auth interceptor
- Reactive forms

## API and Dev Proxy

- Frontend uses relative API paths under `/api` (for backend `/api/v1/...` routes).
- Dev server proxy forwards `/api` to `http://localhost:8080` via `proxy.conf.json`.

Start the app:

```bash
npm install
npm start
```

## Build and Test

Build:

```bash
npm run build
```

Tests:

```bash
npm test -- --watch=false --browsers=ChromeHeadless
```

If Chrome is not installed locally, set `CHROME_BIN` to a valid Chromium/Chrome executable.
