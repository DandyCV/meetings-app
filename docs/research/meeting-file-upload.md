# Research: optimal implementation of the meeting file-upload plan

Investigated against primary sources only: installed gem sources for
`activestorage 8.1.3.1`, `activejob 8.1.3.1`, `actionpack 8.1.3.1`, `marcel 1.2.1`,
`rack 3.2.7` (under `~/.asdf/installs/ruby/4.0.6/lib/ruby/gems/4.0.0/gems/`, abbreviated
`<gems>/` below), the repo's own code, `apps/frontend/AGENTS.md` / `HEROUI_AGENTS.md`,
and MDN / Playwright doc conventions.

## Verdict

**The plan is fundamentally sound and can be implemented close to as written.** The
storage-enablement sequence is correct, the hand-rolled validations are the right call
(Rails 8.1 Active Storage still ships *no* `validates`-style helpers), content-type
checking is stronger than the plan realises (Active Storage sniffs with Marcel by
default), `send_data` is acceptable for a 25 MB cap, `dependent`/purge already works,
and the `:test` Active Job adapter behaves synchronously in 8.1 so `have_enqueued_job`
assertions are valid.

Top 3 things to change:

1. **Frontend download URL is double-prefixed.** `downloadAttachment` builds
   `` `${API_URL}${attachment.download_url}` `` where `API_URL` already ends in `/api/v1`
   and `download_url` starts with `/api/v1` → `http://localhost:3001/api/v1/api/v1/…`.
   Build the download URL from the API *origin*, not `API_URL`. Also add a
   `response.ok` guard and defer `revokeObjectURL`.
2. **RSpec never cleans `tmp/storage`.** With the `:test` queue adapter the blob
   `PurgeJob` is only *enqueued*, never run, and there is no Active Storage teardown in
   `spec/`. Add an `after(:suite)` hook that wipes the disk service root.
3. **Make the blob-purge-on-destroy contract explicit.** Write
   `has_one_attached :file, dependent: :purge_later` (it is the default, but the plan's
   acceptance criterion 4 and spec depend on it) and note the purge is asynchronous;
   optionally call `attachment.file.purge` in `RemoveMeetingAttachment` for a
   synchronous disk delete.

Secondary: use HeroUI `AlertDialog` instead of a hand-rolled `role="dialog"`; serve
downloads with `blob.content_type_for_serving`; consider
`config.active_storage.draw_routes = false` as hardening; drop the pointless dynamic
`import("@/lib/meetings")` in the component.

---

## 1. Enabling Active Storage in an API-only app that started without it

**Plan says:** uncomment `require "active_storage/engine"` in `application.rb:8`; run
`bin/rails active_storage:install`; hand-write `config/storage.yml` (`test` + `local`
Disk services); set `config.active_storage.service` in development/test/production.

**Primary source says:**

- `<gems>/activestorage-8.1.3.1/lib/tasks/activestorage.rake` — `active_storage:install`
  *only* invokes `active_storage:install:migrations` (copies the
  `create_active_storage_tables` migration via the railtie's `install:migrations`
  mechanism). It does **not** generate `config/storage.yml` and does **not** edit
  `config/environments/*`. It has no dependency on `storage.yml` already existing.
  → The plan's manual `storage.yml` + per-env `service` settings are **required and
  correct**.
- `<gems>/activestorage-8.1.3.1/lib/active_storage/engine.rb`,
  `initializer "active_storage.services"` — on boot it reads
  `config/storage/#{Rails.env}.yml` then falls back to `config/storage.yml`, and
  **raises** `"Couldn't find Active Storage configuration in …"` if neither exists. So
  `storage.yml` must be in place before the app next boots — plan Step 4 covers it.
- `<gems>/…/active_storage/attached/model.rb` `validate_global_service_configuration`
  raises `"Missing Active Storage service name…"` at the first `has_one_attached` call
  if `Rails.configuration.active_storage.service` is `nil` and the blob table exists.
  → every environment that boots the model (dev, test, prod, CI) needs
  `config.active_storage.service` set. Plan sets all three env files. Good.
- `config.load_defaults 8.1` (`application.rb:23`) — **version does not matter** for
  enablement. `engine.rb` hard-codes the analyzer/previewer/`content_types_*` defaults
  unconditionally; there is no `load_defaults`-gated Active Storage behaviour that
  affects this feature.
- **Routes the engine mounts:** `engine.rb` sets
  `ActiveStorage.routes_prefix = "/rails/active_storage"` and
  `ActiveStorage.draw_routes = (config != false)` (default **true**). Enabling the
  engine therefore mounts the blob / representation / **disk-service** / proxy routes.
  The disk route (`/rails/active_storage/disk/:encoded_key/*filename`) is signed with
  `secret_key_base` and expires (`ActiveStorage.service_urls_expire_in ||= 5.minutes`)
  but is **unauthenticated**. The spec's threat model says "attachment blobs must never
  be reachable without an authenticated, authorized request". No payload in this
  feature exposes a signed id or a `/rails/active_storage/*` URL, so real risk is low,
  but a clean hardening is `config.active_storage.draw_routes = false` (they build
  their own JWT-guarded `download` route; `rails_blob_path` helpers are unused).
- `ActiveStorage::SetCurrent` is a concern on `ActiveStorage::BaseController` only; it
  populates `ActiveStorage::Current.url_options` from the request for the built-in
  controllers / `url_for(blob)`. This app builds URLs by hand and won't use the
  built-in controllers → **no action needed** (and none if `draw_routes = false`).
- **Variant / analyzer deps:** none needed. `engine.rb` rescues `LoadError` for
  libvips/`image_processing` and merely logs a warning. But note
  `<gems>/…/app/models/active_storage/attachment.rb:36` —
  `after_create_commit :analyze_blob_later` enqueues an `ActiveStorage::AnalyzeJob` for
  **every** attachment. Under `:test` it is enqueued-not-run (fine); under `:async` in
  dev it runs and no-ops without ffprobe/poppler (harmless). Keep
  `have_enqueued_job(ProcessMeetingAttachmentJob)` **class-scoped** (the plan does) so
  the extra `AnalyzeJob` / `PurgeJob` enqueues don't trip `.exactly(:once)` or
  `not_to have_enqueued_job`.

**Recommendation:** implement the sequence as written. Add:
`config.active_storage.draw_routes = false` in `application.rb` (or per-env) as
hardening consistent with the spec's "no public blob URLs" constraint; if omitted, at
least document that the `/rails/active_storage` routes exist and why they are
acceptable. `.gitignore` already ignores `/storage/*` and `/tmp/storage/*`
(`apps/backend/.gitignore:24-29`) — no change there; optionally add
`storage/.keep` + `tmp/storage/.keep`. `app/operations/` is picked up automatically by
Zeitwerk (Rails adds every `app/*` subdir) — no `autoload_paths` change.

---

## 2. Model-level file validations

**Plan says:** hand-rolled `validate :file_presence`, `:file_within_size_limit`,
`:file_content_type_allowed` on `has_one_attached :file`.

**Primary source says:**

- `grep -rn "validates" <gems>/activestorage-8.1.3.1/lib` → **nothing**. Rails 8.1
  Active Storage ships **no** `validates … content_type:/size:/limit:` support. Those
  options belong to the third-party `active_storage_validations` gem, which is **not**
  bundled and which the spec forbids ("No new runtime gems"). The Rails Active Storage
  guide still carries the "Active Storage does not support validations" note.
  → hand-rolled `validate` methods are the **correct** choice.
- **Timing — is `byte_size`/`content_type` available before upload?** Yes.
  `<gems>/…/active_storage/attached/changes/create_one.rb:12` — `CreateOne#initialize`
  calls `blob.identify_without_saving`. `find_or_build_blob` (same file, lines 69-76)
  builds the blob with `ActiveStorage::Blob.build_after_unfurling(io: attachable.open,
  …)`. `<gems>/…/active_storage/blob.rb:258-272` — `unfurl` sets
  `self.byte_size = io.size` and `self.content_type = extract_content_type(io)`
  **immediately, with no upload and no `AnalyzeJob`**. So at `attachment.valid?` time
  `file.attached?` is true and `file.byte_size` / `file.content_type` are populated
  from the in-memory IO. This is exactly the mechanism `active_storage_validations`
  itself relies on. The plan's validations work as written.
- Analysis (`AnalyzeJob`) only adds `metadata` (image dimensions, audio duration…); it
  is **not** needed for `byte_size`. Empty-file detection via `file.byte_size.zero?`
  is reliable.

**Recommendation:** keep hand-rolled. Minor: the three `validate` methods can be one;
keep the error strings so they satisfy the request-spec regexes — `full_messages`
prefixes `"File "`, giving `"File is larger than the 25 MB limit"` (matches `/limit/i`)
and `"File type application/x-msdownload is not allowed"` (matches `/not allowed/i`).
`enum :processing_status, { pending: "pending", … }, default: :pending` is valid 8.1
syntax (string-backed enum). Add a comment that these run against a not-yet-uploaded
blob.

---

## 3. Content-type spoofing

**Plan says:** validate `file.content_type` against `ALLOWED_CONTENT_TYPES`; the spec
notes `marcel` is already bundled.

**Primary source says:** Active Storage **already sniffs server-side by default**.

- `<gems>/…/blob.rb:271` — `self.content_type = extract_content_type(io) if
  content_type.nil? || identify`, and `identify` defaults to **true** in
  `create_and_upload!` / `build_after_unfurling` (`blob.rb:88-107`).
- `blob.rb:366-368` — `extract_content_type(io) = Marcel::MimeType.for(io, name:
  filename.to_s, declared_type: content_type)`.
- `<gems>/marcel-1.2.1/lib/marcel/mime_type.rb:29-31` — `for` returns
  `most_specific_type(for_data(<magic bytes>), for_declared_type(<client header>),
  for_name(<filename>), BINARY)`. `for_data` (actual magic-number inspection) is the
  primary candidate; the declared header only wins when it is a *more specific
  descendant* of the magic type (`most_specific_type`, lines 84-90 — the comment calls
  out MS Office).
- Consequence: `evil.exe` renamed `nice.pdf` with `Content-Type: application/pdf` →
  magic detects `application/x-msdownload`, which is unrelated to `application/pdf`, so
  `blob.content_type == "application/x-msdownload"` → fails the allowlist. The plan's
  own model spec (`filename: "a.exe"`, content `"hello"`) passes for this reason.

**Recommendation:** keep validating `blob.content_type` — it is Marcel's sniffed type,
not the raw header. An explicit `Marcel::MimeType.for(io)` call in the model is
**redundant**; never pass `identify: false`. Document the residual gaps (acceptable,
and virus scanning is explicitly out of scope):
- ZIP-container formats (`docx`/`xlsx`/`pptx`) are magic-detected as `application/zip`
  and only resolved to the specific OOXML type via filename/declared type — so a
  `.zip` renamed `.docx` passes the allowlist.
- Magic-less formats (`text/plain`) fall back to the declared type / extension.
Add a one-line code comment so a future reader doesn't "harden" it redundantly.

---

## 4. Upload flow through the controller

**Plan says:** `params.dig(:attachment, :file)` → `ActionDispatch::Http::UploadedFile`
→ `.attach()`; no strong params; `422 :unprocessable_content`.

**Primary source says:**

- `params.dig(:attachment, :file)` returns the nested `UploadedFile` and does **not**
  raise `UnpermittedParameters` (`dig` bypasses strong-params filtering). Passing an
  `ActionDispatch::Http::UploadedFile` straight to `attach` is a first-class path:
  `create_one.rb:69-76` has an explicit `when ActionDispatch::Http::UploadedFile`
  branch (and `when Rack::Test::UploadedFile` at 77-84 for request specs).
- **API-only multipart:** `config.api_only = true` (`application.rb:41`) trims
  middleware but keeps `ActionDispatch::Http::Parameters`; multipart parsing is done by
  `Rack::Multipart` in the request object, not by a removable middleware. No middleware
  to add. `Rack::Cors` is `insert_before 0` (`config/initializers/cors.rb`) and allows
  `post`/`delete`/`options` with `headers: :any` from the frontend origin — covers the
  multipart POST and the DELETE.
- **Strong params** genuinely not needed: there is no `Model.new(params)` mass
  assignment; the operation builds the record and attaches one explicitly pulled file.
  Consistent with "controllers only compose operations".
- **`:unprocessable_content`** — confirmed:
  `Rack::Utils::SYMBOL_TO_STATUS_CODE[:unprocessable_content] == 422` in rack 3.2.7.
  `apps/backend/app/controllers/api/v1/meetings_controller.rb:27` already uses it.
  (`:content_too_large` → 413 also exists, but the spec pins every failure to 422 —
  keep 422.)

**Recommendation:** implement as written. Doc note only: a production reverse proxy
(nginx `client_max_body_size`, etc.) must allow ≥25 MB bodies; Rack's
`multipart_file_limit` (default 128) counts *file parts*, not bytes, so a single 25 MB
file is unaffected.

---

## 5. Download endpoint

**Plan says:** `send_data blob.download, filename:, type:, disposition: "attachment"`.

**Primary source says:**

- `blob.download` (no block) reads the **entire** file into a Ruby `String` (Disk
  service) → up to 25 MB resident per in-flight request. `send_data` is available in
  `ActionController::API` — `<gems>/actionpack-8.1.3.1/lib/action_controller/api.rb:129`
  includes `DataStreaming`. **No `ActionController::Live` needed.**
- `ActiveStorage::Streaming#send_blob_stream(blob, disposition:)`
  (`<gems>/…/app/controllers/concerns/active_storage/streaming.rb`) streams chunked via
  `blob.download { |chunk| stream.write chunk }` and handles `Range`. **But** the
  concern does `include ActionController::Live` — that turns *every* action in the
  controller into a threaded streaming response (own DB connection, breaks transactional
  request specs, awkward error handling). Using it cleanly means a dedicated
  download-only controller. Overkill for a 25 MB cap.
- Redirect to `rails_blob_path(blob, disposition: :attachment)` /
  `rails_storage_redirect` — hands the client a **signed but unauthenticated**, 5-minute
  URL (`engine.rb`: `service_urls_expire_in ||= 5.minutes`). Violates the spec's
  "authenticated, authorized request" constraint. The plan is right to avoid it.

**Recommendation:** keep `send_data blob.download` for the 25 MB cap; document the
memory trade-off (concurrency × ≤25 MB). If memory ever bites, move `download` into its
own controller that `include ActiveStorage::Streaming` and call `send_blob_stream`.
Two small improvements:
- serve with `blob.content_type_for_serving` instead of raw `blob.content_type` — it
  forces `application/octet-stream` for `content_types_to_serve_as_binary` (html, svg,
  xml). Low risk here (disposition is `attachment`, allowlist has no html/svg) but it's
  the idiom Active Storage's own controllers use.
- `send_data` sets `Content-Length` automatically; `Content-Disposition: attachment;
  filename="…"; filename*=UTF-8''…` — the request spec's `.include?("minutes.txt")`
  passes.

---

## 6. `dependent: :destroy` vs `purge` for attachments + blob cleanup

**Plan says:** `MeetingAttachment has_one_attached :file` (no `dependent:` option) +
`attachment.destroy` + `Meeting has_many :meeting_attachments, dependent: :destroy`.

**Primary source says:** the blob **is** purged, asynchronously.

- `<gems>/…/attached/model.rb:104` — `def has_one_attached(name, dependent:
  :purge_later, …)`. Default is `:purge_later`; stored on the reflection (lines 150-158).
- Same file line 126 — `has_one_attached` also declares
  `has_one :"#{name}_attachment", …, dependent: :destroy`, so destroying the
  `MeetingAttachment` always destroys the `ActiveStorage::Attachment` row.
- `<gems>/…/app/models/active_storage/attachment.rb:37` —
  `after_destroy_commit :purge_dependent_blob_later`; lines 150-155 —
  `def purge_dependent_blob_later; blob&.purge_later if dependent == :purge_later; end`,
  where `dependent` reads the host reflection's option.
- So `meeting_attachment.destroy` → destroys the `Attachment` row → `after_destroy_commit`
  → `blob.purge_later` enqueues `ActiveStorage::PurgeJob` (deletes the blob row **and**
  the file on disk). `Meeting#destroy` → `dependent: :destroy` → each `MeetingAttachment`
  destroyed → same chain. Acceptance criterion 4 is met — **no leak in principle**.

**Risks:**
- The purge is `after_*_commit` + `purge_later` (async). Under the `:test` queue
  adapter `PurgeJob` is enqueued but never run, so `tmp/storage` files pile up during a
  test run (see §12).
- `after_destroy_commit` fires in transactional request specs (Rails runs
  after-commit callbacks in transactional tests). The plan's "deleting the parent
  meeting removes its attachments" example asserts `MeetingAttachment.count`, which is
  the synchronous `dependent: :destroy` — safe regardless.

**Recommendation:**
- Write `has_one_attached :file, dependent: :purge_later` **explicitly** (documents the
  behaviour the spec/AC-4 rely on).
- In `RemoveMeetingAttachment`, optionally call `attachment.file.purge` (synchronous)
  before/instead of relying on the async hook, so the disk file is gone immediately —
  nice if any spec later asserts the file is absent.
- Do **not** write `dependent: :destroy` on `has_one_attached` — not a valid value
  (only `:purge_later`, `:purge`, `false`).

---

## 7. Active Job `:test` adapter + `have_enqueued_job`

**Plan says:** `config.active_job.queue_adapter = :test` in `config/environments/test.rb`;
assert `have_enqueued_job(ProcessMeetingAttachmentJob).exactly(:once)` inside the
operation/request `expect { … }` block; `perform_later(attachment)` after `save`.

**Primary source says:**

- Placement is right. It is also already the **default**:
  `<gems>/activejob-8.1.3.1/lib/active_job/railtie.rb` `active_job.set_configs` —
  `options.queue_adapter ||= (Rails.env.test? ? :test : :async)`. The explicit line is
  redundant-but-harmless and states intent. Keep it.
- **`enqueue_after_transaction_commit`:**
  `<gems>/activejob-8.1.3.1/lib/active_job/enqueuing.rb:53` —
  `class_attribute :enqueue_after_transaction_commit, …, default: false`. The railtie
  mixes in `EnqueueAfterTransactionCommit` (railtie line 29) but **does not change the
  default**, and `railties-8.1.3.1/lib/rails/application/configuration.rb` sets only
  `active_job.retry_jitter` — nothing for this attribute. So in Rails 8.1 the default
  is **`false` → jobs enqueue immediately**, not deferred to `after_commit`.
  → Inside `AttachMeetingFile#call`, `perform_later` enqueues synchronously and
  `have_enqueued_job` sees it within the `expect { }` block even under transactional
  fixtures. **The plan's assertions are valid as written.**
  (If anyone later sets `config.active_job.enqueue_after_transaction_commit = true`,
  the operation-spec `expect { described_class.call }.to have_enqueued_job` would break
  — the test's outer transaction never commits. Worth a one-line comment.)
- `perform_later(attachment)` runs only after `attachment.save` succeeds → the record
  has an id → GlobalID serialisation is fine. (An unsaved record raises at enqueue —
  not our path.)
- `queue_as :default` — no conflict with `ActiveStorage.queues[:analysis]/[:purge]`
  (both default to `nil` → `:default`).

**Recommendation:** no change. `ActiveJob::TestHelper` (plan includes it per-spec) is
needed only if a spec later calls `perform_enqueued_jobs`; `have_enqueued_job` comes
from `rspec-rails` and works without it.

---

## 8. Frontend: `apiFetch` FormData

**Plan says:** when `body instanceof FormData`, omit `Content-Type` and skip
`JSON.stringify`; `export const API_URL`.

**Current code** (`apps/frontend/src/lib/api.ts:23-34`): hard-codes
`"Content-Type": "application/json"` and always `JSON.stringify(body)`.

**Primary source (MDN Fetch / FormData):** when a `FormData` object is passed as
`body`, the browser sets `Content-Type: multipart/form-data; boundary=…`
automatically. Setting it manually omits the boundary and the server cannot parse the
body. The fix must therefore **not set** `Content-Type` for FormData — which the plan's
patch does (`if (!isFormData) headers["Content-Type"] = "application/json"`). Body:
`isFormData ? body : JSON.stringify(body)`; `body === undefined ? undefined : …`.

**Recommendation:** apply the patch as written. It preserves token handling and the
existing response/`ApiError` parsing (a 204 → `data = null` → `apiFetch<void>` returns
`null`). Exporting `API_URL` is fine; alternatively expose a helper that returns the
API origin (see §9/§10).

---

## 9. Frontend download with JWT + HeroUI components

**Plan says:** `fetch(url, { headers: { Authorization } })` → `res.blob()` →
`URL.createObjectURL` → programmatic `<a download>` click → `revokeObjectURL`. Hand-rolled
`role="dialog"` confirm; `Chip` status badge; bare `<input type="file">`.

**Primary source (MDN):** a plain `<a href={download_url}>` cannot carry an
`Authorization` header and the endpoint is JWT-guarded → 401. The
fetch→blob→object-URL→anchor pattern is the MDN-documented way to download
authenticated binary data. Verdict: right approach, but the plan's `downloadAttachment`
has bugs:

1. **Double `/api/v1` prefix (blocking).** `` `${API_URL}${attachment.download_url}` ``
   = `http://localhost:3001/api/v1` + `/api/v1/meetings/…/download`. `API_URL`
   (`api.ts:1`, default `http://localhost:3001/api/v1`) already contains `/api/v1`; the
   backend's `download_url` also starts `/api/v1` (request spec asserts exactly that).
   Fix on the **frontend**: use the origin — e.g.
   `new URL(API_URL).origin + attachment.download_url` — or add a tiny
   `apiOrigin()` / `downloadUrl(path)` helper in `api.ts`. Do not change the backend
   contract.
2. **No `response.ok` check** → on 401/404 the error JSON gets saved as a file. Guard
   and throw so the component surfaces an error.
3. **`revokeObjectURL` called synchronously after `click()`** can cancel the download
   in some browsers (MDN: the object URL must outlive the download start). Defer it:
   `setTimeout(() => { link.remove(); URL.revokeObjectURL(url); }, 0)`.
4. Filename: keep using `attachment.filename` (CORS won't expose `Content-Disposition`
   without an `expose` rule; not worth adding).

**HeroUI v3** (`apps/frontend/HEROUI_AGENTS.md` index + `apps/frontend/.heroui-docs/react/`):

- **No file-input / dropzone primitive exists** (no "file" component in the index; the
  spec forbids upload libraries) → a visually-hidden native `<input type="file">`
  triggered by a styled `Button` (`components/(buttons)/button.mdx`) is the correct
  approach. Keep an accessible name ("Upload file") on the input.
- **Confirm dialog:** use `AlertDialog`
  (`components/(overlays)/alert-dialog.mdx`; demos `alert-dialog/statuses.tsx`,
  `custom-trigger.tsx`) rather than the hand-rolled `role="dialog"` div — it provides
  the focus trap, `Esc`, `aria-modal`, and the destructive-confirm pattern that the
  Phase D `ui-ux-pro-max` gate will otherwise flag. `Modal` (`modal.mdx`) is the
  fallback; `AlertDialog` is the semantically correct one.
- **Status badge:** `Chip` (`data-display/chip.mdx`, has `color` + `statuses`) is fine;
  `Badge` (`badge.mdx`) is more for counts/dots. Keep the **text** label always
  rendered (not colour-only) per spec AC 16/22.
- **Inline feedback:** `Alert` (`feedback/alert.mdx`) + `Spinner`
  (`feedback/spinner.mdx`). The compound API (`Alert.Indicator` / `Alert.Content` / …)
  shifts between v3 alphas — verify against `alert.mdx` before writing (the plan's Task
  7 note already says so).
- Drop the `const { uploadAttachment } = await import("@/lib/meetings")` inside the
  component — it re-imports the module the component already imports from. Use the
  static import.

**Recommendation:** apply approach as planned with the four `downloadAttachment` fixes;
swap the hand-rolled dialog for `AlertDialog`; read
`alert-dialog.mdx` / `button.mdx` / `chip.mdx` / `alert.mdx` / `spinner.mdx` first.

---

## 10. Next.js 16 App Router specifics

**Plan says:** `"use client"` component that calls Rails directly; no Route Handler.

**Primary source (`apps/frontend/node_modules/next/dist/docs/`, per `AGENTS.md`):**

- The component is a client component using `useEffect` + `useState` for auth'd,
  client-only data — the exact pattern the existing
  `apps/frontend/src/app/meetings/[id]/page.tsx` already uses. Next 16's server-side
  churn (async request APIs, `params` as a Promise in **server** components, caching
  defaults) does not apply to a `"use client"` component; `useParams()` is a client
  hook and is unaffected. Read the client-components guide under
  `node_modules/next/dist/docs/` to confirm nothing else, but there is no RSC/streaming
  concern here.
- **CORS / proxy:** there is **no** Next rewrite/proxy in the repo — the browser calls
  `http://localhost:3001` cross-origin directly (`NEXT_PUBLIC_API_URL`). Backend CORS
  (`apps/backend/config/initializers/cors.rb`): `origins
  ENV.fetch("FRONTEND_ORIGIN", "http://localhost:3000")`, `resource "/api/*"`,
  `methods: [get post put patch delete options head]`, `headers: :any`. This covers the
  multipart upload (POST), the DELETE, and the download `fetch` (path
  `/api/v1/meetings/…/download` matches `/api/*`). No `expose` header is needed (the
  client reads the response body, not headers). **No Next config change required.**

**Recommendation:** proceed. Only real Next-specific action: skim the client-component
doc as `AGENTS.md` mandates, and keep the `<!-- BEGIN:nextjs-agent-rules -->` block in
`AGENTS.md` committed as-is.

---

## 11. Playwright file upload

**Plan says:** `page.getByLabel("Upload file").setInputFiles(FIXTURE)` on a native
`<input type="file">`.

**Primary source (Playwright docs):** `locator.setInputFiles()` works on an
`<input type="file">` **regardless of visibility** — it is the documented way to drive
the "styled button hiding a native input" pattern. The `fileChooser` event
(`page.on('filechooser')` + trigger click) is only needed when there is no input
element to target (e.g. an OS-native dialog). The plan's `getByLabel` approach is
correct **provided the `<input>` is the element the accessible name resolves to**
(the plan's `aria-label="Upload file"` on the input satisfies this).

**Recommendation:**
- Keep the input mounted in the DOM (don't conditionally unmount it) and hidden via
  `sr-only`/opacity, not `display:none` removal — `setInputFiles` still works either
  way but a persistently-present input is the robust choice.
- `path.join(__dirname, "support/fixtures/sample.txt")` — the repo has no `"type":
  "module"` in the root/e2e `package.json`, so specs are CJS and `__dirname` is
  defined. If e2e is ever switched to ESM, replace with `import.meta.dirname`.

---

## 12. RSpec + Active Storage test hygiene

**Plan says:** `config.active_storage.service = :test` + `config.active_job.queue_adapter
= :test` in `config/environments/test.rb`; `spec/fixtures/files/sample.txt` +
in-memory `Rack::Test::UploadedFile`.

**Primary source / current state:**

- `apps/backend/spec/rails_helper.rb` / `spec_helper.rb` — **no** existing Active
  Storage or Active Job config, `use_transactional_fixtures = true`,
  `fixture_paths = [Rails.root.join('spec/fixtures')]`. Adding the two lines to
  `test.rb` **conflicts with nothing** (grep confirms no other `queue_adapter`), and
  `:test` is already the framework default for the test env (§7).
- `config.active_storage.service = :test` is the right knob (env config, not a runtime
  assignment). The `:test` Disk service root is `tmp/storage` per the plan's
  `storage.yml`.
- **`tmp/storage` is never cleaned.** DB rows roll back with the transaction, but files
  written to disk during a spec are not removed, and under the `:test` adapter the
  `ActiveStorage::PurgeJob` from a destroy is only *enqueued* (§6). Rails' own test
  suite clears the dir in `ActiveSupport::TestCase` teardown; **RSpec has no
  equivalent**. The plan omits this — add to Phase A:

  ```ruby
  # spec/support/active_storage.rb  (and require spec/support in rails_helper)
  RSpec.configure do |config|
    config.after(:suite) do
      root = ActiveStorage::Blob.service.try(:root)
      FileUtils.rm_rf(root) if root && root.to_s.include?("tmp")
    end
  end
  ```

  (`.gitignore` already ignores `/tmp/storage/*`, so uncleaned files never get
  committed — this is about disk hygiene / flakiness, not the repo.)
- `config.eager_load = ENV["CI"].present?` — in CI, eager loading loads
  `app/operations/meetings/*` and `ProcessMeetingAttachmentJob`. Zeitwerk expects
  `app/operations/meetings/attach_meeting_file.rb` → `Meetings::AttachMeetingFile`;
  `app/operations` is auto-added as a root (no config needed). Confirmed `app/operations`
  does not yet exist — it's new, and fine.
- `ActiveRecord::Migration.maintain_test_schema!` in `rails_helper.rb:33` — after the
  new migrations, first `bin/rspec` run auto-loads the schema (or run
  `RAILS_ENV=test bin/rails db:prepare`). Plan Task 10 Step 1 already anticipates this.
- `rspec-rails` provides `have_enqueued_job` without `ActiveJob::TestHelper`; the plan
  including the helper per-spec is harmless and future-proofs `perform_enqueued_jobs`.

**Recommendation:** add the `tmp/storage` `after(:suite)` cleanup (Phase A DoD). Keep
both `test.rb` lines. No other test-config change.

---

## Concrete changes to the plan

- [ ] **§9/§10 — fix the download URL.** `downloadAttachment` must hit the API
      *origin*, not `API_URL` (which already includes `/api/v1`, as does the backend's
      `download_url`). Add an `apiOrigin()`/`downloadUrl()` helper or use
      `new URL(API_URL).origin`. Keep the backend contract unchanged.
- [ ] **§9 — harden `downloadAttachment`:** add `if (!response.ok) throw …`; defer
      `link.remove()` + `URL.revokeObjectURL(url)` to a `setTimeout(…, 0)`.
- [ ] **§12 — add `tmp/storage` cleanup** to RSpec (`after(:suite)` wiping
      `ActiveStorage::Blob.service.root`); list it in the Phase A Definition of Done.
- [ ] **§6 — make purge explicit:** `has_one_attached :file, dependent: :purge_later`;
      note in the model / memory that blob purge on destroy is asynchronous
      (`ActiveStorage::PurgeJob`). Optionally `attachment.file.purge` in
      `RemoveMeetingAttachment`.
- [ ] **§9 — use HeroUI `AlertDialog`** for the delete confirmation instead of the
      hand-rolled `role="dialog"` div (focus trap / Esc / `aria-modal` for free; the
      Phase D UI gate will otherwise flag it). Read `alert-dialog.mdx` first.
- [ ] **§9 — drop the dynamic `import("@/lib/meetings")`** inside `MeetingAttachments`;
      use the static import.
- [ ] **§5 — serve downloads with `blob.content_type_for_serving`** (not raw
      `blob.content_type`).
- [ ] **§3 — add a code comment** in the model that `blob.content_type` is Marcel's
      sniffed type (`identify: true` by default), so it isn't "hardened" redundantly;
      never pass `identify: false`.
- [ ] **§1 — add `config.active_storage.draw_routes = false`** (hardening consistent
      with the spec's "no public blob URLs"), or explicitly document why the
      `/rails/active_storage/*` routes are acceptable.
- [ ] **§1 — note** that `app/operations/` needs no `autoload_paths` entry (Zeitwerk
      auto-adds it) and optionally add `storage/.keep` + `tmp/storage/.keep`.
- [ ] **§11 — keep the file `<input>` permanently mounted** and hidden via `sr-only`,
      not conditionally unmounted; note `__dirname` is valid only while e2e stays CJS.
- [ ] **§7 — no change, but add a comment** that the assertions rely on
      `enqueue_after_transaction_commit` being `false` (the Rails 8.1 default).
- [ ] **§2/§7 — no change:** hand-rolled validations and the `:test` adapter approach
      are correct; `byte_size`/`content_type` are available pre-upload.

## Source index

| Claim | Source |
|---|---|
| `active_storage:install` only copies migrations | `<gems>/activestorage-8.1.3.1/lib/tasks/activestorage.rake` |
| storage.yml required at boot, `/rails/active_storage` routes, 5-min URLs, `draw_routes` default | `<gems>/activestorage-8.1.3.1/lib/active_storage/engine.rb` |
| `has_one_attached(dependent: :purge_later)` default; `_attachment` `dependent: :destroy` | `<gems>/activestorage-8.1.3.1/lib/active_storage/attached/model.rb:104,126,150` |
| no `validates` helpers in Active Storage | `grep -rn validates <gems>/activestorage-8.1.3.1/lib` (empty) |
| `byte_size`/`content_type` set at unfurl, no upload; Marcel sniff with `identify: true` | `<gems>/activestorage-8.1.3.1/lib/active_storage/blob.rb:258-272,366-368` |
| `CreateOne` accepts `ActionDispatch::Http::UploadedFile` / `Rack::Test::UploadedFile` | `<gems>/activestorage-8.1.3.1/lib/active_storage/attached/changes/create_one.rb:69-84` |
| `after_destroy_commit :purge_dependent_blob_later` → `blob.purge_later` | `<gems>/activestorage-8.1.3.1/app/models/active_storage/attachment.rb:37,150-155` |
| `AnalyzeJob` enqueued per attachment | `<gems>/activestorage-8.1.3.1/app/models/active_storage/attachment.rb:36` |
| `send_blob_stream` pulls in `ActionController::Live` | `<gems>/activestorage-8.1.3.1/app/controllers/concerns/active_storage/streaming.rb` |
| `Marcel::MimeType.for` — magic primary, declared only if more specific | `<gems>/marcel-1.2.1/lib/marcel/mime_type.rb:29-90` |
| `ActionController::API` includes `DataStreaming`, not `Live`/`Streaming` | `<gems>/actionpack-8.1.3.1/lib/action_controller/api.rb:116-149` |
| `enqueue_after_transaction_commit` default `false` | `<gems>/activejob-8.1.3.1/lib/active_job/enqueuing.rb:53`; `railtie.rb:29` |
| `:test` is the default queue adapter for the test env | `<gems>/activejob-8.1.3.1/lib/active_job/railtie.rb` (`set_configs`) |
| `:unprocessable_content`/`:content_too_large` → 422/413 in rack 3.2.7 | `ruby -e 'Rack::Utils::SYMBOL_TO_STATUS_CODE'` |
| repo has `rack-cors` allowing `/api/*` POST/DELETE from `:3000` | `apps/backend/config/initializers/cors.rb` |
| current `apiFetch` hard-codes JSON content-type | `apps/frontend/src/lib/api.ts:23-34` |
| HeroUI v3 has `AlertDialog`, `Chip`, `Alert`, `Button`, no file component | `apps/frontend/HEROUI_AGENTS.md` index |
