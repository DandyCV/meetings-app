# CLAUDE.md — backend

Rails 8.1 API-only, Ruby 4.0, PostgreSQL 17, RSpec. JWT auth. See the repo-root `CLAUDE.md` for
monorepo layout and cross-cutting project rules.

## Database

PostgreSQL. Run `docker compose up -d` (from repo root) for a local server matching the
`config/database.yml` defaults — host `localhost:5432`, user/password `meetings_app`,
databases `meetings_app_development` / `meetings_app_test` (the test DB is auto-created by
Rails). Connection settings are overridable via `DATABASE_HOST` / `DATABASE_PORT` /
`DATABASE_USERNAME` / `DATABASE_PASSWORD`; production reads `DATABASE_URL`. CI runs against a
`postgres:17` service container.

## Commands (run from repo root unless noted)

| Task | Command |
|---|---|
| Tests | `npm test` (= `cd apps/backend && bin/rspec`) |
| Lint | `npm run lint:backend` (RuboCop) |
| Format | `rubocop -A` (via `npm run format`) |
| Console / migrate | `cd apps/backend && bin/rails c` / `bin/rails db:migrate` |

After changing anything under `engines/`, run `cd apps/backend && bundle install`.

## Architecture

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

### Conventions

- Style: RuboCop Rails Omakase (`.rubocop.yml`). Notable: spaces inside array/hash literal
  brackets (`[ "a" ]`), double quotes, no `# frozen_string_literal` comment.
- Controllers render plain hashes as JSON (no serializer lib). Error shape: `{ error: "..." }`
  (401/…) or `{ errors: [...] }` (422 `:unprocessable_content`).
- `User.email` is normalized (strip + downcase) via `normalizes`; password min length 8.

## Testing

- RSpec under `apps/backend/spec/`, organized by module — `spec/auth/`, `spec/users/`,
  `spec/requests/`, `spec/models/`. One host suite (no per-engine dummy apps). Transactional
  fixtures, no FactoryBot — plain `Users::User.create!` / operation calls.
- New/changed behavior → request specs in `spec/requests/` (plus operation specs in
  `spec/auth|users/` when adding a `Cqrs::Command`/`Query`).
- Before finishing backend work: `npm test` **and** `npm run test:e2e` must be green, plus
  `npm run lint:backend`. See memory `testing-discipline`.
