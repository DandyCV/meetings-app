# CLAUDE.md

Monorepo: Next.js frontend + Rails API backend. Meetings app with JWT auth.

## Layout

```
apps/frontend/   Next.js 16, App Router, TS, HeroUI v3, Tailwind v4   (npm workspace "frontend")
apps/backend/    Rails 8.1 API-only, Ruby 4.0, PostgreSQL 17, RSpec
apps/backend/engines/{cqrs,auth,users}   backend modules as path-gems
e2e/             Playwright end-to-end tests (repo root)
```

## Nested docs — read the one for the app you're touching

- `apps/backend/CLAUDE.md` — backend architecture, CQRS engine split, conventions, testing.
- `apps/frontend/CLAUDE.md` — frontend architecture + conventions. Imports `AGENTS.md`
  (Next.js is heavily modified from training data — read `node_modules/next/dist/docs/`
  before writing frontend code) and `HEROUI_AGENTS.md`.

## Commands (run from repo root)

| Task | Command |
|---|---|
| Database (local) | `docker compose up -d` — PostgreSQL 17 on :5432 (user/pass/db `meetings_app`) |
| Dev (both apps) | `npm run dev` — frontend :3000, backend :3001 |
| Backend tests | `npm test` (= `cd apps/backend && bin/rspec`) |
| E2E tests | `npm run test:e2e` (first run: `npx playwright install chromium`) |
| Lint | `npm run lint` / `npm run lint:fix` (ESLint + RuboCop) |
| Format | `npm run format` (Prettier + `rubocop -A`) |
| Build | `npm run build` |

App-specific commands (console, migrate, per-suite runs) live in each app's `CLAUDE.md`.

**Before starting a server for FE/BE validation, check whether it is already running** — probe
`http://localhost:3000` (frontend) / `http://localhost:3001/up` (backend) and reuse a live one
instead of launching a duplicate (which will fail on the busy port). `npm run test:e2e` already
reuses running servers locally.

## Backend at a glance

API-only Rails. Routes: `POST /api/v1/registrations`, `POST /api/v1/sessions`, `GET /api/v1/me`,
`GET /api/v1/meetings`, `GET /api/v1/meetings/:id`, `POST /api/v1/meetings` (all meeting routes
scoped to `current_user`). Auth = JWT bearer token (HS256, `secret_key_base`, 24h exp, payload
`{ user_id }`). Business logic lives in three path-gem engines (`cqrs`, `auth`, `users`) —
see `apps/backend/CLAUDE.md` and memory `backend-cqrs-engine-split`.

## Frontend at a glance

App Router pages `/login`, `/register`, `/` (protected — lists meetings), `/meetings/new`
(protected — create form), `/meetings/[id]` (protected — meeting detail). `useAuth()` from
`src/context/AuthContext.tsx`, `apiFetch` from `src/lib/api.ts`, meeting helpers in
`src/lib/meetings.ts`, JWT in `localStorage`.
UI is HeroUI v3 only. See `apps/frontend/CLAUDE.md`.

## Testing

- Backend: RSpec under `apps/backend/spec/`. See `apps/backend/CLAUDE.md`.
- E2E: `e2e/auth.spec.ts` (register/login/logout/guards). Playwright boots Rails in `test`
  env on :3001 and Next dev on :3000 automatically; each test uses a random
  `e2e-…@example.com` account (no seeding). See memory `e2e-auth-tests`.
- CI: `.github/workflows/ci.yml` runs on every PR to `main` and every push to `main` — parallel `backend`
  (`bin/ci`), `frontend` (lint + format:check + build), and `e2e` jobs, each against a
  `postgres:17` service container.

## Project rules

- **Tests after every code change.** Run the relevant suite after each change and before
  reporting done — `npm test` for backend, `npm run test:e2e` for frontend, both for
  anything touching the API contract. Never hand back code with a red or unrun suite.
- **Every feature ships with tests.** Backend behavior → request specs in
  `apps/backend/spec/requests/` (plus operation specs when adding a `Cqrs::Command`/`Query`).
  User-facing frontend behavior → an E2E spec in `e2e/`. Not complete until both layers pass.
- **Keep docs in sync with architecture.** Whenever you change the project's architecture
  (module/engine split, routes, auth model, data flow, app layout, tech stack), update the
  affected `CLAUDE.md` files (root and the relevant `apps/*/CLAUDE.md`) and any related
  memory in the same change. Not done until the docs match the code.
- **All repo content in English** (code, comments, commits, branch names). See memory
  `english-only-project-content`.
- `@types/react` / `@types/react-dom` must stay in the ROOT `package.json` devDependencies
  (npm-workspace hoisting — see memory `npm-workspaces-types-react-hoisting`).
- Don't commit or push unless asked. Branch off `main` first.
- Screenshots: after any user-facing frontend change, capture the affected page(s) with
  `/run` or Playwright and save every screenshot to `screenshots/` at the repo root — never
  elsewhere, never `/tmp`. The dir is gitignored (kept via `.gitkeep`); throwaway artifacts.
