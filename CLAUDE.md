# CLAUDE.md

Monorepo: Next.js frontend + Rails API backend. Meetings app with JWT auth.

## Layout

```
apps/frontend/   Next.js 16, App Router, TS, HeroUI v3, Tailwind v4   (npm workspace "frontend")
apps/backend/    Rails 8.1 API-only, Ruby 4.0, SQLite, RSpec
apps/backend/engines/{cqrs,auth,users}   backend modules as path-gems (see below)
e2e/             Playwright end-to-end tests (repo root)
```

Nested docs: `apps/frontend/AGENTS.md` (Next.js is heavily modified from training data — read
`node_modules/next/dist/docs/` before writing frontend code) and `apps/frontend/HEROUI_AGENTS.md`.

## Commands (run from repo root)

| Task | Command |
|---|---|
| Dev (both apps) | `npm run dev` — frontend :3000, backend :3001 |
| Backend tests | `npm test` (= `cd apps/backend && bin/rspec`) |
| E2E tests | `npm run test:e2e` (first run: `npx playwright install chromium`) |
| Lint | `npm run lint` / `npm run lint:fix` (ESLint + RuboCop) |
| Format | `npm run format` (Prettier + `rubocop -A`) |
| Build | `npm run build` |
| Backend console/migrate | `cd apps/backend && bin/rails c` / `bin/rails db:migrate` |

After changing anything under `apps/backend/engines/`, run `cd apps/backend && bundle install`.

## Backend architecture

API-only Rails. Routes: `POST /api/v1/registrations`, `POST /api/v1/sessions`, `GET /api/v1/me`,
`GET /api/v1/meetings`. Auth = JWT bearer token (HS256, `secret_key_base`, 24h exp, payload
`{ user_id }`).

### Module split (CQRS boundary) — see memory `backend-cqrs-engine-split`

Business logic lives in three path-gem engines, wired in `apps/backend/Gemfile` (order: cqrs first):

- **`cqrs`** (plain gem): `Cqrs::Command` / `Cqrs::Query` — both `extend Cqrs::Callable` → class
  method `.call(**)`. `Cqrs::Result.success(value)` / `.failure(errors)` for fallible commands.
- **`auth`** engine: tokens only, zero knowledge of `User`/AR.
  - `Auth::GenerateToken.call(user_id:, expires_at: 24.hours.from_now)` → JWT string
  - `Auth::VerifyToken.call(token:)` → `user_id` or `nil`
  - `Auth::TokenCodec` — internal JWT wrapper, not called directly
- **`users`** engine: owns `Users::User` (namespaced, `self.table_name = "users"`).
  - `Users::RegisterUser.call(email:, password:, password_confirmation:)` → `Cqrs::Result`
  - `Users::AuthenticateUser.call(email:, password:)` → `Users::User` or `nil`
  - `Users::FindUser.call(id:)` → `Users::User` or `nil`

**Rules:**
- Controllers and other modules NEVER touch `Users::User` or token internals directly — always go
  through the `Auth::*` / `Users::*` operations. Controllers only compose them
  (`application_controller.rb`, `sessions_controller.rb`, `registrations_controller.rb`).
- `auth` must not reference `Users`; `users` must not reference tokens. Keep it that way.
- New use case → new `Cqrs::Command`/`Cqrs::Query` subclass in the owning engine's
  `app/operations/<module>/`. One operation per file, `initialize` takes kwargs, logic in `#call`.
- Engines are NOT `isolate_namespace`; namespacing is by directory.
- Migrations and `db/schema.rb` stay in `apps/backend/db/` (host), never in engines.
- `Meeting` (host model, `app/models/meeting.rb`) `belongs_to :user, class_name: "Users::User"`.
- Gem deps: `jwt` → `auth.gemspec`, `bcrypt` → `users.gemspec` (not host Gemfile).

### Backend conventions

- Style: RuboCop Rails Omakase (`.rubocop.yml`). Notable: spaces inside array/hash literal
  brackets (`[ "a" ]`), double quotes, no `# frozen_string_literal` comment.
- Controllers render plain hashes as JSON (no serializer lib). Error shape: `{ error: "..." }`
  (401/…) or `{ errors: [...] }` (422 `:unprocessable_content`).
- `User.email` is normalized (strip + downcase) via `normalizes`; password min length 8.

## Frontend architecture

- `src/context/AuthContext.tsx` — `useAuth()` exposes `{ user, isLoading, login, register, logout }`.
  Token in `localStorage` (`src/lib/token.ts`), in-memory user for re-renders. On mount, hydrates
  user from `GET /me` if a token exists.
- `src/lib/api.ts` — `apiFetch<T>(path, { method, body, token })`; throws `ApiError`
  (`.status`, `.message`, `.errors`). Base URL from `NEXT_PUBLIC_API_URL`
  (default `http://localhost:3001/api/v1`, see `apps/frontend/.env.local`).
- Pages: `/login`, `/register` (HeroUI `Form`/`TextField`), `/` (protected — redirects to `/login`
  when no user; lists meetings).
- UI: HeroUI v3 components only (`@heroui/react`), Tailwind v4 utility classes, `next-themes` for
  light/dark. Follow `HEROUI_AGENTS.md`.

## Testing

- Backend: RSpec under `apps/backend/spec/`, organized by module — `spec/auth/`, `spec/users/`,
  `spec/requests/`, `spec/models/`. One host suite (no per-engine dummy apps). Transactional
  fixtures, no FactoryBot — plain `Users::User.create!` / operation calls.
- E2E: `e2e/auth.spec.ts` (register/login/logout/guards). Playwright boots Rails in `test` env on
  :3001 and Next dev on :3000 automatically; each test uses a random `e2e-…@example.com` account
  (no seeding). See memory `e2e-auth-tests`.
- Before finishing backend work: `npm test` **and** `npm run test:e2e` must be green, plus
  `npm run lint:backend`.

## Project rules

- **Tests after every code change.** Run the relevant suite after each change and before
  reporting done — `npm test` for backend changes, `npm run test:e2e` for frontend changes,
  both for anything touching the API contract. Never hand back code with a red or unrun suite.
- **Every feature ships with tests.** New/changed backend behavior → request specs in
  `apps/backend/spec/requests/` (plus operation specs in `spec/auth|users/` when adding a
  `Cqrs::Command`/`Query`). New/changed user-facing frontend behavior → an E2E spec in `e2e/`.
  A feature is not complete until both layers cover it and pass.
- **All repo content in English** (code, comments, commits, branch names). See memory
  `english-only-project-content`.
- `@types/react` / `@types/react-dom` must stay in the ROOT `package.json` devDependencies
  (npm-workspace hoisting — see memory `npm-workspaces-types-react-hoisting`).
- Don't commit or push unless asked. Branch off `main` first.
- Screenshots: after any user-facing frontend change, capture the affected page(s) with `/run`
  or Playwright and save every screenshot to `screenshots/` at the repo root — never elsewhere,
  never `/tmp`. The dir is gitignored (kept via `.gitkeep`); these are throwaway review artifacts.
- The `<!-- BEGIN:nextjs-agent-rules -->` block in `apps/frontend/AGENTS.md` is regenerated by
  `next dev` — commit it with your work, don't fight it.
