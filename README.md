# meetings-app

A monorepo containing two applications:

- **`apps/frontend`** — Next.js (TypeScript, App Router, ESLint, Prettier), UI built with
  [HeroUI](https://heroui.com) v3 (free/open-source `@heroui/react`) on Tailwind CSS v4, with
  `next-themes` for automatic light/dark mode. Includes email/password login and registration
  pages, token-based auth (JWT stored in `localStorage`), and a protected home page (`/`)
  listing the user's meetings.
- **`apps/backend`** — Ruby on Rails API (RuboCop with Omakase style, Brakeman, bundler-audit).
  Exposes `POST /api/v1/sessions` (login), `POST /api/v1/registrations` (sign up),
  `GET /api/v1/me` and `GET /api/v1/meetings`, all authenticated via a JWT bearer token.

## Requirements

- Node.js >= 20, npm >= 10
- Ruby >= 3.2 (tested on 4.0), Bundler
- SQLite3 (default local database for Rails)

## Setup

```bash
npm run setup
```

Installs npm dependencies for the frontend (npm workspaces) and Ruby gems + database
for the backend (`bin/setup` in `apps/backend`).

## Running

```bash
npm run dev              # runs frontend (http://localhost:3000) and backend (http://localhost:3001) in parallel
npm run dev:frontend     # Next.js only
npm run dev:backend      # Rails only (bin/rails server, forced to port 3001 via `dev:backend`)
```

The frontend reads the API base URL from `NEXT_PUBLIC_API_URL` (see
`apps/frontend/.env.local`, defaults to `http://localhost:3001/api/v1`).

### Demo data

```bash
cd apps/backend && bin/rails db:seed
```

Seeds a demo user (`demo@example.com` / `password123`) with a handful of
sample meetings, useful for trying out the login flow locally.

## Testing

```bash
npm run test            # RSpec (backend)
npm run test:backend    # same, explicit
```

Backend tests live under `apps/backend/spec` (model specs and API request specs).

### End-to-end (Playwright)

```bash
npm run test:e2e        # full-stack browser tests (registration, login, logout)
npm run test:e2e:ui     # same, in Playwright's interactive UI mode
```

E2E specs live under `e2e/` and exercise the real UI against a live stack.
Playwright boots the Rails API in the `test` environment on port 3001 and the
Next.js dev server on port 3000 automatically (existing servers are reused
locally). First run only: `npx playwright install chromium`.

## Linting and formatting

```bash
npm run lint            # ESLint (frontend) + RuboCop (backend)
npm run lint:fix        # auto-fix both projects
npm run format          # Prettier (frontend) + RuboCop -A (backend)
npm run format:check    # check formatting without making changes
```

Per project:

```bash
npm run lint:frontend / lint:backend
npm run lint:fix:frontend / lint:fix:backend
npm run format:frontend / format:backend
```

## Build

```bash
npm run build            # production build of Next.js
```

## Structure

```
apps/
  frontend/   # Next.js application
  backend/    # Rails API application
```

Each application keeps its own `.gitignore` and linter/formatter config, and is
fully self-contained (can be developed and deployed independently). The root
`package.json` uses npm workspaces only for convenient cross-project scripts
(`dev`, `lint`, `format`, `build`).
