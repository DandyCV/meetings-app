# Meeting File Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a meeting owner upload, list, download, and delete files attached to one of their meetings, with each attachment carrying a `pending → processed/failed` processing status for a future processing feature to hook into.

**Architecture:** Enable Rails Active Storage on the API-only backend. A new host model `MeetingAttachment` `belongs_to :meeting` and `has_one_attached :file`; it owns the app-level metadata Active Storage does not (`processing_status`, `processed_at`). Writes go through three host-app CQRS operations (`Meetings::AttachMeetingFile`, `Meetings::RemoveMeetingAttachment`, `Meetings::ListMeetingAttachments`) composed by a nested `Api::V1::AttachmentsController`. A successful upload enqueues a placeholder `ProcessMeetingAttachmentJob`. The frontend gains `FormData` support in `apiFetch`, attachment helpers in `src/lib/meetings.ts`, and an `Attachments` section on the meeting detail page built with HeroUI v3.

**Tech Stack:** Rails 8.1 API-only, Ruby 4.0, PostgreSQL 17, Active Storage (disk service), Active Job (`:test` adapter in tests), RSpec. Next.js 16 App Router, TypeScript, HeroUI v3, Tailwind v4. Playwright E2E.

**Spec:** `docs/specs/meeting-file-upload/spec.md` — read it alongside this plan. Every decision here is argued from that spec.

## Global Constraints

- **TDD, non-negotiable.** For every task: write the failing test, run it, watch it fail for the right reason, write the minimum code to pass, run it green, then refactor. No production code without a failing test driving it. (`docs/specs/meeting-file-upload/spec.md` → Testing Decisions → Process: TDD.)
- **All repo content in English** — code, comments, commits, branch names, test data. (memory `english-only-project-content`.)
- **Tests after every change.** `npm test` (backend RSpec) for backend work, `npm run test:e2e` (Playwright) for frontend work, both for anything touching the API contract. Never leave a red or unrun suite. (memory `testing-discipline`.)
- **Backend conventions** (`apps/backend/CLAUDE.md`): RuboCop Rails Omakase — double quotes, spaces inside array/hash literal brackets (`[ "a" ]`), no `# frozen_string_literal`. Controllers render plain hashes as JSON, no serializer. Error shape: `{ error: "..." }` for 401/404, `{ errors: [ ... ] }` for 422 `:unprocessable_content`. Migrations and `db/schema.rb` stay in `apps/backend/db/`, never in engines.
- **CQRS boundary** (memory `backend-cqrs-engine-split`): `Cqrs::Command` / `Cqrs::Query` base classes come from the `cqrs` engine; both `extend Cqrs::Callable` giving a class-level `.call(**)`. Fallible commands return `Cqrs::Result.success(value)` / `Cqrs::Result.failure(errors)`. `Meeting` is a **host** model; attachment operations are a `Meeting` concern and live on the host app under `app/operations/meetings/`, NOT in an engine. Controllers only compose operations.
- **Frontend conventions** (`apps/frontend/CLAUDE.md`): UI is HeroUI v3 (`@heroui/react`) + Tailwind v4 utilities only. Read the relevant guide in `apps/frontend/node_modules/next/dist/docs/` before writing frontend code, and `apps/frontend/HEROUI_AGENTS.md` before using HeroUI components. Route guards follow the existing pattern (`useAuth()`, redirect to `/login` when no user). Token via `getToken()` from `src/lib/token.ts`.
- **UI/UX review is a completion gate** (memory `ui-review-after-ui-changes`): any UI change is not done until you have (1) booted the app and screenshotted the affected page in its relevant states/breakpoints into `screenshots/` at the repo root, and (2) run it through the `ui-ux-pro-max` skill and fixed what it flags.
- **Max file size:** 25 MB. **Allowed content types:** `application/pdf`, `text/plain`, `image/png`, `image/jpeg`, `image/gif`, `image/webp`, `audio/mpeg`, `audio/wav`, `audio/mp4`, `video/mp4`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `application/vnd.ms-powerpoint`, `application/vnd.openxmlformats-officedocument.presentationml.presentation`, `application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`. Backend is authoritative; the frontend mirrors these values for pre-upload convenience checks only.
- **API upload field:** `multipart/form-data`, single file at `attachment[file]`.
- **`download_url`** in every attachment JSON payload is a **relative** path: `/api/v1/meetings/:meeting_id/attachments/:id/download`.
- **Don't commit or push to `main`.** Branch off `main` first (e.g. `feat/meeting-file-upload`). Commit after every green step.

---

## Phases

This plan is split into four independent phases. Each phase is a self-contained,
independently testable unit that a single subagent can own end-to-end (its own
suite green before hand-off). Dependencies flow one direction only: a phase starts
from the previous phase's merged branch; no phase depends on a sibling in flight.
Dispatch phases with `superpowers:subagent-driven-development`.

| Phase | Tasks | Deliverable (all tests green) | Depends on | Suite to run |
|---|---|---|---|---|
| **A — Storage foundation** | 1, 2 | Active Storage enabled; `MeetingAttachment` model with validations; `ProcessMeetingAttachmentJob` placeholder. Model + job specs green. | `main` | `npm test`, `npm run lint:backend` |
| **B — Operations + API** | 3, 4, 5, 6 | Three `Meetings::*` operations; nested `AttachmentsController` (index/create/download/destroy); `attachments_count` on the meeting payload. Operation + request specs green. | Phase A merged | `npm test`, `npm run lint:backend` |
| **C — Frontend** | 7 | `apiFetch` FormData support; `meetings.ts` attachment helpers; `MeetingAttachments` section on the detail page. E2E spec green. | Phase B merged (needs the live API) | `npm run typecheck`, `npm run lint:frontend`, `npm run test:e2e` |
| **D — Review + docs** | 8, 9, 10 | UI/UX review applied + screenshots; `CLAUDE.md` ×3 + memory updated; full-suite green; PR opened. | Phase C merged | `npm test`, `npm run lint`, `npm run typecheck`, `npm run build`, `npm run test:e2e` |

Each phase is committed on its own branch off the previous phase's tip (or `main`
for A) and merged before the next phase starts. Within a phase, follow the
task/step order as written. Each phase below opens with a **Definition of Done**
checklist — the phase is not finished until every box is ticked.

---

## File Structure

### Backend — created

| File | Responsibility |
|---|---|
| `apps/backend/db/migrate/<ts>_create_active_storage_tables.active_storage.rb` | Active Storage's three tables (generated by `bin/rails active_storage:install`). |
| `apps/backend/db/migrate/<ts>_create_meeting_attachments.rb` | `meeting_attachments` table: `meeting_id` FK, `processing_status` string (default `"pending"`, not null), `processed_at` datetime nullable, timestamps. |
| `apps/backend/config/storage.yml` | Active Storage service definitions: `test` and `local` disk services. |
| `apps/backend/app/models/meeting_attachment.rb` | The attachment record: `belongs_to :meeting`, `has_one_attached :file`, `processing_status` enum, size/content-type/presence validations, `MAX_FILE_SIZE` + `ALLOWED_CONTENT_TYPES` constants. |
| `apps/backend/app/operations/meetings/attach_meeting_file.rb` | `Cqrs::Command`: build + save a `MeetingAttachment` with the uploaded file on a given meeting; on success enqueue `ProcessMeetingAttachmentJob`; return `Cqrs::Result`. |
| `apps/backend/app/operations/meetings/remove_meeting_attachment.rb` | `Cqrs::Command`: find an attachment within a meeting's scope and destroy it (purging the blob); return `Cqrs::Result`. |
| `apps/backend/app/operations/meetings/list_meeting_attachments.rb` | `Cqrs::Query`: return a meeting's attachments, oldest first, with the `file` blob eager-loaded. |
| `apps/backend/app/controllers/api/v1/attachments_controller.rb` | Nested REST controller: `index`, `create`, `download`, `destroy`. Resolves the meeting in `current_user` scope (404 otherwise), composes the operations, serialises attachments to plain hashes. |
| `apps/backend/app/jobs/process_meeting_attachment_job.rb` | Placeholder processing job: advances one attachment out of `pending`. Carries a `TODO` pointing at the future processing spec. |
| `apps/backend/spec/models/meeting_attachment_spec.rb` | Model spec: validity, enum default, each validation. |
| `apps/backend/spec/operations/meetings/attach_meeting_file_spec.rb` | Operation spec: success wraps the attachment, enqueues one job; failures on missing/empty/oversize/disallowed file. |
| `apps/backend/spec/operations/meetings/remove_meeting_attachment_spec.rb` | Operation spec: destroys within scope; failure when the id is not on the meeting. |
| `apps/backend/spec/operations/meetings/list_meeting_attachments_spec.rb` | Operation spec: returns only that meeting's attachments, oldest first. |
| `apps/backend/spec/jobs/process_meeting_attachment_job_spec.rb` | Job spec: moves `pending` → `processed`, sets `processed_at`. |
| `apps/backend/spec/requests/api/v1/meeting_attachments_spec.rb` | Request specs: the full API contract (see spec → Seam 1). |
| `apps/backend/spec/fixtures/files/sample.txt` | Small text fixture for upload specs. (Oversize/empty/disallowed inputs are built in-memory inside the specs — no fixture files.) |

### Backend — modified

| File | Change |
|---|---|
| `apps/backend/config/application.rb:8` | Uncomment `require "active_storage/engine"`. |
| `apps/backend/config/environments/development.rb` | Add `config.active_storage.service = :local`. |
| `apps/backend/config/environments/test.rb` | Add `config.active_storage.service = :test` and `config.active_job.queue_adapter = :test`. |
| `apps/backend/config/environments/production.rb` | Add `config.active_storage.service = :local` (kept simple; cloud service is out of scope per the spec). |
| `apps/backend/db/schema.rb` | Regenerated by running the migrations — do not hand-edit. |
| `apps/backend/app/models/meeting.rb` | Add `has_many :meeting_attachments, dependent: :destroy` (with `inverse_of: :meeting`). |
| `apps/backend/config/routes.rb` | Nest `resources :attachments, only: [ :index, :create, :destroy ]` (plus `get :download, on: :member`) under `resources :meetings`. |
| `apps/backend/app/controllers/api/v1/meetings_controller.rb` | `meeting_json` gains `attachments_count: meeting.meeting_attachments.count`. |
| `apps/backend/spec/requests/api/v1/meetings_spec.rb` | Add one example: `GET /api/v1/meetings/:id` includes an accurate `attachments_count`. |

### Frontend — created

| File | Responsibility |
|---|---|
| `apps/frontend/src/app/meetings/[id]/MeetingAttachments.tsx` | `"use client"` component: loads a meeting's attachments, renders the upload control, the list (filename, size, type, uploaded-at, status badge, download, delete-with-confirm), the empty state, busy state, and inline success/error feedback. Re-fetches after upload/delete. |

### Frontend — modified

| File | Change |
|---|---|
| `apps/frontend/src/lib/api.ts` | `apiFetch` accepts a `FormData` body: skip `Content-Type` and `JSON.stringify` when the body is `FormData`. Export `API_URL`. |
| `apps/frontend/src/lib/meetings.ts` | Add `ProcessingStatus` + `MeetingAttachment` types, `MAX_ATTACHMENT_BYTES` + `ALLOWED_ATTACHMENT_TYPES` constants, `fetchAttachments`, `uploadAttachment`, `deleteAttachment`, `downloadAttachment`, `formatFileSize`. `Meeting` type gains `attachments_count: number`. |
| `apps/frontend/src/app/meetings/[id]/page.tsx` | Render `<MeetingAttachments meetingId={state.meeting.id} />` in the `status === "ready"` branch, below the meeting `Card`. |

### E2E — created / modified

| File | Change |
|---|---|
| `e2e/meeting-attachments.spec.ts` | New spec (see spec → Seam 2): empty state, upload → row with filename + "Pending" badge, delete → row gone. |
| `e2e/support/fixtures/sample.txt` | Small text fixture for the upload. |
| `e2e/support/helpers.ts` | Add `createMeetingViaUi(page, { title, startsAt })` helper (does not alter existing helpers). |

### Docs — modified (Task 10)

`CLAUDE.md` (root), `apps/backend/CLAUDE.md`, `apps/frontend/CLAUDE.md`, and the memory directory.

---

# Phase A — Storage foundation

> Branch: `feat/meeting-attachments-storage` off `main`. Deliverable: Tasks 1–2 with model + job specs green. Merge before Phase B.

### Definition of Done — Phase A

- [ ] Task 1 and Task 2 complete, each step committed.
- [ ] `apps/backend/config/application.rb` loads `active_storage/engine`; `config/storage.yml` has `test` + `local` disk services; dev/test/prod each set `config.active_storage.service`; test env sets `config.active_job.queue_adapter = :test`.
- [ ] `db/schema.rb` `version:` matches the `create_meeting_attachments` migration and contains the three `active_storage_*` tables plus `meeting_attachments`.
- [ ] `cd apps/backend && bin/rspec spec/models/meeting_attachment_spec.rb spec/jobs/process_meeting_attachment_job_spec.rb` — all green.
- [ ] `npm test` — full backend suite green (existing specs unaffected).
- [ ] `npm run lint:backend` — green.
- [ ] `MeetingAttachment` exposes `MAX_FILE_SIZE`, `ALLOWED_CONTENT_TYPES`, the `processing_status` enum (default `pending`); `Meeting has_many :meeting_attachments, dependent: :destroy`.
- [ ] No frontend or route changes in this phase.
- [ ] Branch merged to `main`.

## Task 1: Enable Active Storage + `MeetingAttachment` model

**Files:**
- Modify: `apps/backend/config/application.rb:8`
- Modify: `apps/backend/config/environments/development.rb`
- Modify: `apps/backend/config/environments/test.rb`
- Modify: `apps/backend/config/environments/production.rb`
- Create: `apps/backend/config/storage.yml`
- Create: `apps/backend/db/migrate/<ts>_create_active_storage_tables.active_storage.rb` (generated)
- Create: `apps/backend/db/migrate/<ts>_create_meeting_attachments.rb`
- Modify: `apps/backend/db/schema.rb` (regenerated)
- Create: `apps/backend/app/models/meeting_attachment.rb`
- Modify: `apps/backend/app/models/meeting.rb`
- Test: `apps/backend/spec/models/meeting_attachment_spec.rb`

**Interfaces:**
- Produces:
  - `MeetingAttachment` — `belongs_to :meeting`; `has_one_attached :file`; `processing_status` string enum with values `"pending"`, `"processed"`, `"failed"` (default `"pending"`); `processed_at` datetime, nullable. Predicate/bang methods from the enum: `pending?`, `processed!`, etc.
  - `MeetingAttachment::MAX_FILE_SIZE` → `25.megabytes` (Integer).
  - `MeetingAttachment::ALLOWED_CONTENT_TYPES` → frozen `Array<String>` (the list in Global Constraints).
  - `Meeting#meeting_attachments` → `ActiveRecord::Associations::CollectionProxy`, `dependent: :destroy`.

- [ ] **Step 1: Branch**

```bash
git checkout main && git pull
git checkout -b feat/meeting-attachments-storage
```

- [ ] **Step 2: Enable the Active Storage engine**

In `apps/backend/config/application.rb`, change line 8 from:

```ruby
# require "active_storage/engine"
```

to:

```ruby
require "active_storage/engine"
```

- [ ] **Step 3: Generate the Active Storage migration**

Run:

```bash
cd apps/backend && bin/rails active_storage:install
```

Expected: creates `db/migrate/<ts>_create_active_storage_tables.active_storage.rb`. Do not edit the generated file.

- [ ] **Step 4: Create `config/storage.yml`**

The generator does not create this in an API-only app that started without Active Storage. Create `apps/backend/config/storage.yml`:

```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

- [ ] **Step 5: Wire the service per environment**

In `apps/backend/config/environments/development.rb`, inside the `Rails.application.configure do` block, add:

```ruby
  # Store uploaded files on the local file system (see config/storage.yml).
  config.active_storage.service = :local
```

In `apps/backend/config/environments/production.rb`, inside the configure block, add the same line (cloud storage is out of scope for this spec):

```ruby
  config.active_storage.service = :local
```

In `apps/backend/config/environments/test.rb`, inside the configure block, add:

```ruby
  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  # Assert enqueued jobs without running them.
  config.active_job.queue_adapter = :test
```

- [ ] **Step 6: Write the `meeting_attachments` migration**

Create `apps/backend/db/migrate/<ts>_create_meeting_attachments.rb` (use a timestamp AFTER the Active Storage migration). Get the timestamp with `date -u +%Y%m%d%H%M%S`.

```ruby
class CreateMeetingAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_attachments do |t|
      t.references :meeting, null: false, foreign_key: true
      t.string :processing_status, null: false, default: "pending"
      t.datetime :processed_at

      t.timestamps
    end
  end
end
```

- [ ] **Step 7: Run the migrations**

Run:

```bash
cd apps/backend && bin/rails db:migrate
```

Expected: both migrations run; `db/schema.rb` is regenerated with `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`, and `meeting_attachments`. The schema `version:` bumps to your `meeting_attachments` timestamp.

- [ ] **Step 8: Write the failing model spec**

Create `apps/backend/spec/models/meeting_attachment_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MeetingAttachment, type: :model do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def build_attachment(filename: "notes.txt", content_type: "text/plain", content: "hello")
    attachment = meeting.meeting_attachments.build
    attachment.file.attach(
      io: StringIO.new(content), filename: filename, content_type: content_type
    )
    attachment
  end

  it "is valid with a meeting and an allowed, non-empty, within-limit file" do
    expect(build_attachment).to be_valid
  end

  it "defaults processing_status to pending" do
    expect(MeetingAttachment.new.processing_status).to eq("pending")
  end

  it "requires a meeting" do
    attachment = MeetingAttachment.new
    attachment.valid?
    expect(attachment.errors[:meeting]).to be_present
  end

  it "requires a file to be attached" do
    attachment = meeting.meeting_attachments.build
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end

  it "rejects an empty file" do
    attachment = build_attachment(content: "")
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end

  it "rejects a file above the size limit" do
    attachment = build_attachment(content: "x" * (MeetingAttachment::MAX_FILE_SIZE + 1))
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end

  it "rejects a disallowed content type" do
    attachment = build_attachment(filename: "a.exe", content_type: "application/x-msdownload")
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end
end
```

- [ ] **Step 9: Run the spec to verify it fails**

Run: `cd apps/backend && bin/rspec spec/models/meeting_attachment_spec.rb`
Expected: FAIL — `uninitialized constant MeetingAttachment`.

- [ ] **Step 10: Write the model**

Create `apps/backend/app/models/meeting_attachment.rb`:

```ruby
class MeetingAttachment < ApplicationRecord
  MAX_FILE_SIZE = 25.megabytes

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    text/plain
    image/png
    image/jpeg
    image/gif
    image/webp
    audio/mpeg
    audio/wav
    audio/mp4
    video/mp4
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  ].freeze

  belongs_to :meeting

  has_one_attached :file

  enum :processing_status, { pending: "pending", processed: "processed", failed: "failed" },
       default: :pending

  validate :file_presence
  validate :file_within_size_limit
  validate :file_content_type_allowed

  private

  def file_presence
    errors.add(:file, "must be attached") unless file.attached?
  end

  def file_within_size_limit
    return unless file.attached?
    return if file.byte_size.positive? && file.byte_size <= MAX_FILE_SIZE

    if file.byte_size.zero?
      errors.add(:file, "can't be empty")
    else
      errors.add(:file, "is larger than the 25 MB limit")
    end
  end

  def file_content_type_allowed
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, "type #{file.content_type} is not allowed")
  end
end
```

- [ ] **Step 11: Add the association to `Meeting`**

In `apps/backend/app/models/meeting.rb`, add below the `belongs_to :user` line:

```ruby
  has_many :meeting_attachments, dependent: :destroy, inverse_of: :meeting
```

- [ ] **Step 12: Run the model spec to verify it passes**

Run: `cd apps/backend && bin/rspec spec/models/meeting_attachment_spec.rb`
Expected: PASS (all 7 examples).

- [ ] **Step 13: Run the full backend suite + lint**

Run: `npm test && npm run lint:backend`
Expected: all green. The existing `meeting_spec.rb` and request specs still pass.

- [ ] **Step 14: Commit**

```bash
git add apps/backend/config/application.rb apps/backend/config/environments apps/backend/config/storage.yml apps/backend/db apps/backend/app/models
git commit -m "feat: enable Active Storage and add MeetingAttachment model"
```

---

## Task 2: `ProcessMeetingAttachmentJob` placeholder

**Files:**
- Create: `apps/backend/app/jobs/process_meeting_attachment_job.rb`
- Test: `apps/backend/spec/jobs/process_meeting_attachment_job_spec.rb`

**Interfaces:**
- Consumes: `MeetingAttachment` (Task 1).
- Produces: `ProcessMeetingAttachmentJob` — `ApplicationJob` subclass, `queue_as :default`, `#perform(meeting_attachment)` takes a `MeetingAttachment` record (GlobalID-serialised by Active Job) and updates it to `processing_status: "processed"`, `processed_at: Time.current`.

- [ ] **Step 1: Write the failing job spec**

Create `apps/backend/spec/jobs/process_meeting_attachment_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ProcessMeetingAttachmentJob, type: :job do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def create_attachment
    attachment = meeting.meeting_attachments.build
    attachment.file.attach(io: StringIO.new("hello"), filename: "notes.txt",
                           content_type: "text/plain")
    attachment.save!
    attachment
  end

  it "moves the attachment from pending to processed and stamps processed_at" do
    attachment = create_attachment

    expect { described_class.perform_now(attachment) }
      .to change { attachment.reload.processing_status }.from("pending").to("processed")

    expect(attachment.processed_at).to be_present
  end
end
```

- [ ] **Step 2: Run the job spec to verify it fails**

Run: `cd apps/backend && bin/rspec spec/jobs/process_meeting_attachment_job_spec.rb`
Expected: FAIL — `uninitialized constant ProcessMeetingAttachmentJob`.

- [ ] **Step 3: Write the job**

Create `apps/backend/app/jobs/process_meeting_attachment_job.rb`:

```ruby
# Placeholder for the meeting-attachment processing pipeline.
#
# TODO(meeting-file-processing): the real work (transcription, summarisation,
# etc.) is a separate spec. This spec (docs/specs/meeting-file-upload/spec.md)
# only establishes the enqueue seam and the processing_status lifecycle; for now
# the job simply advances the attachment out of "pending".
class ProcessMeetingAttachmentJob < ApplicationJob
  queue_as :default

  def perform(meeting_attachment)
    meeting_attachment.update!(processing_status: :processed, processed_at: Time.current)
  end
end
```

- [ ] **Step 4: Run the job spec to verify it passes**

Run: `cd apps/backend && bin/rspec spec/jobs/process_meeting_attachment_job_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/backend/app/jobs/process_meeting_attachment_job.rb apps/backend/spec/jobs
git commit -m "feat: add placeholder ProcessMeetingAttachmentJob"
```

---

# Phase B — Operations + API

> Branch: `feat/meeting-attachments-api` off the merged Phase A tip. Deliverable: Tasks 3–6 with operation + request specs green. Merge before Phase C.

### Definition of Done — Phase B

- [ ] Tasks 3–6 complete, each step committed.
- [ ] `app/operations/meetings/` contains `attach_meeting_file.rb`, `remove_meeting_attachment.rb`, `list_meeting_attachments.rb`; controllers compose them and never touch `MeetingAttachment` directly except for the read-only `download` lookup.
- [ ] `config/routes.rb` nests `attachments` (`index`, `create`, `destroy`, member `download`) under `meetings`.
- [ ] `cd apps/backend && bin/rspec spec/operations/meetings spec/requests/api/v1/meeting_attachments_spec.rb spec/requests/api/v1/meetings_spec.rb` — all green.
- [ ] `npm test` — full backend suite green.
- [ ] `npm run lint:backend` — green.
- [ ] Manual check against a running backend: `POST` a file → `201` with the documented JSON shape and `processing_status: "pending"`; `GET` list shows it; `GET .../download` returns the bytes with the original filename; `DELETE` → `204` and it is gone; a foreign / unknown `meeting_id` → `404`; no token → `401`.
- [ ] `GET /api/v1/meetings/:id` returns an accurate `attachments_count`.
- [ ] Upload enqueues exactly one `ProcessMeetingAttachmentJob` (asserted in specs).
- [ ] No frontend changes in this phase.
- [ ] Branch merged to `main`.

## Task 3: `Meetings::AttachMeetingFile` operation

**Files:**
- Create: `apps/backend/app/operations/meetings/attach_meeting_file.rb`
- Test: `apps/backend/spec/operations/meetings/attach_meeting_file_spec.rb`
- Create: `apps/backend/spec/fixtures/files/sample.txt`

**Interfaces:**
- Consumes: `MeetingAttachment` (Task 1), `ProcessMeetingAttachmentJob` (Task 2).
- Produces: `Meetings::AttachMeetingFile.call(meeting:, file:)` where `meeting` is a `Meeting` and `file` is an uploaded file object (`ActionDispatch::Http::UploadedFile`) or `nil`. Returns `Cqrs::Result`:
  - success → `result.value` is the persisted `MeetingAttachment`; exactly one `ProcessMeetingAttachmentJob` is enqueued with that attachment.
  - failure → `result.errors` is an `Array<String>` (validation messages); nothing is enqueued; no `MeetingAttachment` row persists.

- [ ] **Step 1: Create the fixture file**

Create `apps/backend/spec/fixtures/files/sample.txt` with the single line:

```
Meeting notes fixture.
```

- [ ] **Step 2: Write the failing operation spec**

Create `apps/backend/spec/operations/meetings/attach_meeting_file_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Meetings::AttachMeetingFile do
  include ActiveJob::TestHelper

  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def uploaded_file(name: "sample.txt", type: "text/plain", content: "hello world")
    file = Tempfile.new(name)
    file.write(content)
    file.rewind
    ActionDispatch::Http::UploadedFile.new(
      tempfile: file, filename: name, type: type
    )
  end

  it "persists an attachment on the meeting and returns it in a success result" do
    result = nil

    expect { result = described_class.call(meeting: meeting, file: uploaded_file) }
      .to change { meeting.meeting_attachments.count }.by(1)

    expect(result).to be_success
    expect(result.value).to be_a(MeetingAttachment)
    expect(result.value.file.filename.to_s).to eq("sample.txt")
    expect(result.value.processing_status).to eq("pending")
  end

  it "enqueues exactly one processing job for the new attachment" do
    expect { described_class.call(meeting: meeting, file: uploaded_file) }
      .to have_enqueued_job(ProcessMeetingAttachmentJob).exactly(:once)
  end

  it "fails when no file is given" do
    result = described_class.call(meeting: meeting, file: nil)

    expect(result).to be_failure
    expect(result.errors).to be_present
    expect(meeting.meeting_attachments.count).to eq(0)
  end

  it "fails on an empty file and enqueues nothing" do
    expect do
      result = described_class.call(meeting: meeting, file: uploaded_file(content: ""))
      expect(result).to be_failure
    end.not_to have_enqueued_job(ProcessMeetingAttachmentJob)
  end

  it "fails on a file above the size limit" do
    big = uploaded_file(content: "x" * (MeetingAttachment::MAX_FILE_SIZE + 1))
    result = described_class.call(meeting: meeting, file: big)

    expect(result).to be_failure
    expect(result.errors.join).to match(/limit/i)
  end

  it "fails on a disallowed content type" do
    result = described_class.call(
      meeting: meeting, file: uploaded_file(name: "a.exe", type: "application/x-msdownload")
    )

    expect(result).to be_failure
    expect(result.errors.join).to match(/not allowed/i)
  end
end
```

- [ ] **Step 3: Run the operation spec to verify it fails**

Run: `cd apps/backend && bin/rspec spec/operations/meetings/attach_meeting_file_spec.rb`
Expected: FAIL — `uninitialized constant Meetings::AttachMeetingFile`.

- [ ] **Step 4: Write the operation**

Create `apps/backend/app/operations/meetings/attach_meeting_file.rb`:

```ruby
module Meetings
  # Command: attach an uploaded file to a meeting as a MeetingAttachment.
  # On success, enqueues the processing job. Returns a Cqrs::Result.
  class AttachMeetingFile < Cqrs::Command
    def initialize(meeting:, file:)
      @meeting = meeting
      @file = file
    end

    def call
      attachment = @meeting.meeting_attachments.build
      attachment.file.attach(@file) if @file.present?

      if attachment.save
        ProcessMeetingAttachmentJob.perform_later(attachment)
        Cqrs::Result.success(attachment)
      else
        Cqrs::Result.failure(attachment.errors.full_messages)
      end
    end
  end
end
```

- [ ] **Step 5: Run the operation spec to verify it passes**

Run: `cd apps/backend && bin/rspec spec/operations/meetings/attach_meeting_file_spec.rb`
Expected: PASS (all 6 examples).

- [ ] **Step 6: Run the full backend suite + lint**

Run: `npm test && npm run lint:backend`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add apps/backend/app/operations/meetings/attach_meeting_file.rb apps/backend/spec/operations apps/backend/spec/fixtures/files/sample.txt
git commit -m "feat: add Meetings::AttachMeetingFile operation"
```

---

## Task 4: `Meetings::ListMeetingAttachments` + `Meetings::RemoveMeetingAttachment` operations

**Files:**
- Create: `apps/backend/app/operations/meetings/list_meeting_attachments.rb`
- Create: `apps/backend/app/operations/meetings/remove_meeting_attachment.rb`
- Test: `apps/backend/spec/operations/meetings/list_meeting_attachments_spec.rb`
- Test: `apps/backend/spec/operations/meetings/remove_meeting_attachment_spec.rb`

**Interfaces:**
- Consumes: `MeetingAttachment` (Task 1).
- Produces:
  - `Meetings::ListMeetingAttachments.call(meeting:)` → an `ActiveRecord::Relation` of that meeting's `MeetingAttachment`s, ordered `created_at: :asc`, with `file_attachment: :blob` eager-loaded.
  - `Meetings::RemoveMeetingAttachment.call(meeting:, id:)` → `Cqrs::Result`. success → `result.value` is the destroyed attachment; failure (`result.errors == [ "Attachment not found" ]`) when `id` is not one of `meeting`'s attachments.

- [ ] **Step 1: Write the failing list-operation spec**

Create `apps/backend/spec/operations/meetings/list_meeting_attachments_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Meetings::ListMeetingAttachments do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }
  let(:other_meeting) { user.meetings.create!(title: "Retro", starts_at: 2.days.from_now) }

  def attach(target, filename)
    a = target.meeting_attachments.build
    a.file.attach(io: StringIO.new("data"), filename: filename, content_type: "text/plain")
    a.save!
    a
  end

  it "returns only the given meeting's attachments, oldest first" do
    first = attach(meeting, "a.txt")
    second = attach(meeting, "b.txt")
    attach(other_meeting, "c.txt")

    expect(described_class.call(meeting: meeting).to_a).to eq([ first, second ])
  end

  it "returns an empty relation when the meeting has no attachments" do
    expect(described_class.call(meeting: meeting)).to be_empty
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd apps/backend && bin/rspec spec/operations/meetings/list_meeting_attachments_spec.rb`
Expected: FAIL — `uninitialized constant Meetings::ListMeetingAttachments`.

- [ ] **Step 3: Write the list operation**

Create `apps/backend/app/operations/meetings/list_meeting_attachments.rb`:

```ruby
module Meetings
  # Query: a meeting's attachments, oldest first, with blobs eager-loaded.
  class ListMeetingAttachments < Cqrs::Query
    def initialize(meeting:)
      @meeting = meeting
    end

    def call
      @meeting.meeting_attachments
              .with_attached_file
              .order(created_at: :asc)
    end
  end
end
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd apps/backend && bin/rspec spec/operations/meetings/list_meeting_attachments_spec.rb`
Expected: PASS.

- [ ] **Step 5: Write the failing remove-operation spec**

Create `apps/backend/spec/operations/meetings/remove_meeting_attachment_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Meetings::RemoveMeetingAttachment do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }
  let(:other_meeting) { user.meetings.create!(title: "Retro", starts_at: 2.days.from_now) }

  def attach(target)
    a = target.meeting_attachments.build
    a.file.attach(io: StringIO.new("data"), filename: "a.txt", content_type: "text/plain")
    a.save!
    a
  end

  it "destroys an attachment that belongs to the meeting" do
    attachment = attach(meeting)

    expect { described_class.call(meeting: meeting, id: attachment.id) }
      .to change { meeting.meeting_attachments.count }.by(-1)
  end

  it "returns success wrapping the destroyed attachment" do
    attachment = attach(meeting)
    result = described_class.call(meeting: meeting, id: attachment.id)

    expect(result).to be_success
    expect(result.value.id).to eq(attachment.id)
  end

  it "fails when the id is not an attachment on this meeting" do
    foreign = attach(other_meeting)
    result = described_class.call(meeting: meeting, id: foreign.id)

    expect(result).to be_failure
    expect(MeetingAttachment.exists?(foreign.id)).to be(true)
  end
end
```

- [ ] **Step 6: Run it to verify it fails**

Run: `cd apps/backend && bin/rspec spec/operations/meetings/remove_meeting_attachment_spec.rb`
Expected: FAIL — `uninitialized constant Meetings::RemoveMeetingAttachment`.

- [ ] **Step 7: Write the remove operation**

Create `apps/backend/app/operations/meetings/remove_meeting_attachment.rb`:

```ruby
module Meetings
  # Command: destroy one of a meeting's attachments (purging its blob).
  class RemoveMeetingAttachment < Cqrs::Command
    def initialize(meeting:, id:)
      @meeting = meeting
      @id = id
    end

    def call
      attachment = @meeting.meeting_attachments.find_by(id: @id)
      return Cqrs::Result.failure([ "Attachment not found" ]) unless attachment

      attachment.destroy
      Cqrs::Result.success(attachment)
    end
  end
end
```

- [ ] **Step 8: Run it to verify it passes**

Run: `cd apps/backend && bin/rspec spec/operations/meetings/remove_meeting_attachment_spec.rb`
Expected: PASS.

- [ ] **Step 9: Run the full backend suite + lint**

Run: `npm test && npm run lint:backend`
Expected: green.

- [ ] **Step 10: Commit**

```bash
git add apps/backend/app/operations/meetings apps/backend/spec/operations/meetings
git commit -m "feat: add list and remove meeting-attachment operations"
```

---

## Task 5: Routes + `AttachmentsController` (index, create)

**Files:**
- Modify: `apps/backend/config/routes.rb`
- Create: `apps/backend/app/controllers/api/v1/attachments_controller.rb`
- Test: `apps/backend/spec/requests/api/v1/meeting_attachments_spec.rb`

**Interfaces:**
- Consumes: all three `Meetings::*` operations (Tasks 3–4).
- Produces:
  - `GET /api/v1/meetings/:meeting_id/attachments` → `200` JSON array; each element:
    ```
    { "id": Integer, "meeting_id": Integer, "filename": String, "byte_size": Integer,
      "content_type": String, "processing_status": "pending"|"processed"|"failed",
      "processed_at": String|null, "created_at": String, "download_url": String }
    ```
  - `POST /api/v1/meetings/:meeting_id/attachments` (multipart, field `attachment[file]`) → `201` with one attachment object, or `422` `{ "errors": [String] }`.
  - Both → `404` `{ "error": "Not found" }` for an unknown / other-user `meeting_id`; `401` `{ "error": "Unauthorized" }` with no/invalid token.
  - Private helper `attachment_json(attachment)` producing the shape above (reused by Task 6).

- [ ] **Step 1: Add the routes**

In `apps/backend/config/routes.rb`, replace:

```ruby
      resources :meetings, only: [ :index, :show, :create ]
```

with:

```ruby
      resources :meetings, only: [ :index, :show, :create ] do
        resources :attachments, only: [ :index, :create, :destroy ] do
          get :download, on: :member
        end
      end
```

- [ ] **Step 2: Write the failing request spec (index + create only for now)**

Create `apps/backend/spec/requests/api/v1/meeting_attachments_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Api::V1::Meeting attachments", type: :request do
  include ActiveJob::TestHelper

  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:other_user) do
    Users::User.create!(email: "john@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:token) { Auth::GenerateToken.call(user_id: user.id) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def upload(name: "sample.txt", type: "text/plain", content: "hello world")
    Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: name)
  end

  def create_attachment(target: meeting, filename: "existing.txt")
    a = target.meeting_attachments.build
    a.file.attach(io: StringIO.new("data"), filename: filename, content_type: "text/plain")
    a.save!
    a
  end

  describe "GET /api/v1/meetings/:meeting_id/attachments" do
    it "returns the meeting's attachments for the owner" do
      created = create_attachment(filename: "agenda.txt")

      get "/api/v1/meetings/#{meeting.id}/attachments", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to eq(1)
      expect(response.parsed_body.first).to include(
        "id" => created.id,
        "meeting_id" => meeting.id,
        "filename" => "agenda.txt",
        "content_type" => "text/plain",
        "processing_status" => "pending",
        "processed_at" => nil,
        "download_url" => "/api/v1/meetings/#{meeting.id}/attachments/#{created.id}/download"
      )
      expect(response.parsed_body.first["byte_size"]).to be_positive
      expect(response.parsed_body.first["created_at"]).to be_present
    end

    it "returns an empty array when there are none" do
      get "/api/v1/meetings/#{meeting.id}/attachments", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns 404 for another user's meeting" do
      foreign = other_user.meetings.create!(title: "Not mine", starts_at: 1.day.from_now)

      get "/api/v1/meetings/#{foreign.id}/attachments", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the meeting does not exist" do
      get "/api/v1/meetings/999999/attachments", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "rejects unauthenticated requests" do
      get "/api/v1/meetings/#{meeting.id}/attachments"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/meetings/:meeting_id/attachments" do
    it "creates an attachment and returns it with a pending status" do
      expect do
        post "/api/v1/meetings/#{meeting.id}/attachments",
             params: { attachment: { file: upload(name: "deck.txt") } },
             headers: auth_headers
      end.to change { meeting.meeting_attachments.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "filename" => "deck.txt",
        "processing_status" => "pending"
      )
      expect(response.parsed_body["id"]).to be_present
    end

    it "enqueues exactly one processing job" do
      expect do
        post "/api/v1/meetings/#{meeting.id}/attachments",
             params: { attachment: { file: upload } }, headers: auth_headers
      end.to have_enqueued_job(ProcessMeetingAttachmentJob).exactly(:once)
    end

    it "keeps both files when two uploads share a filename" do
      2.times do
        post "/api/v1/meetings/#{meeting.id}/attachments",
             params: { attachment: { file: upload(name: "notes.txt") } },
             headers: auth_headers
      end

      get "/api/v1/meetings/#{meeting.id}/attachments", headers: auth_headers
      expect(response.parsed_body.map { |a| a["filename"] }).to eq([ "notes.txt", "notes.txt" ])
    end

    it "returns 422 when no file is given" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: {} }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns 422 for an empty file" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload(content: "") } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for a disallowed content type" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload(name: "a.exe", type: "application/x-msdownload") } },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for a file over the size limit" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload(content: "x" * (MeetingAttachment::MAX_FILE_SIZE + 1)) } },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for another user's meeting" do
      foreign = other_user.meetings.create!(title: "Not mine", starts_at: 1.day.from_now)

      post "/api/v1/meetings/#{foreign.id}/attachments",
           params: { attachment: { file: upload } }, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "rejects unauthenticated requests" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload } }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

- [ ] **Step 3: Run the request spec to verify it fails**

Run: `cd apps/backend && bin/rspec spec/requests/api/v1/meeting_attachments_spec.rb`
Expected: FAIL — routing error / `uninitialized constant Api::V1::AttachmentsController`.

- [ ] **Step 4: Write the controller**

Create `apps/backend/app/controllers/api/v1/attachments_controller.rb`:

```ruby
module Api
  module V1
    class AttachmentsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_meeting

      # GET /api/v1/meetings/:meeting_id/attachments
      def index
        attachments = Meetings::ListMeetingAttachments.call(meeting: @meeting)
        render json: attachments.map { |attachment| attachment_json(attachment) }
      end

      # POST /api/v1/meetings/:meeting_id/attachments
      def create
        result = Meetings::AttachMeetingFile.call(
          meeting: @meeting, file: params.dig(:attachment, :file)
        )

        if result.success?
          render json: attachment_json(result.value), status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end

      private

      def set_meeting
        @meeting = current_user.meetings.find_by(id: params[:meeting_id])
        render json: { error: "Not found" }, status: :not_found unless @meeting
      end

      def attachment_json(attachment)
        blob = attachment.file
        {
          id: attachment.id,
          meeting_id: attachment.meeting_id,
          filename: blob.filename.to_s,
          byte_size: blob.byte_size,
          content_type: blob.content_type,
          processing_status: attachment.processing_status,
          processed_at: attachment.processed_at&.iso8601,
          created_at: attachment.created_at.iso8601,
          download_url: "/api/v1/meetings/#{attachment.meeting_id}/attachments/#{attachment.id}/download"
        }
      end
    end
  end
end
```

- [ ] **Step 5: Run the request spec to verify it passes**

Run: `cd apps/backend && bin/rspec spec/requests/api/v1/meeting_attachments_spec.rb`
Expected: PASS (index + create groups; `download`/`destroy` are added in Task 6).

- [ ] **Step 6: Run the full backend suite + lint**

Run: `npm test && npm run lint:backend`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add apps/backend/config/routes.rb apps/backend/app/controllers/api/v1/attachments_controller.rb apps/backend/spec/requests/api/v1/meeting_attachments_spec.rb
git commit -m "feat: add attachments API index and create endpoints"
```

---

## Task 6: `AttachmentsController` download + destroy, and `attachments_count` on the meeting payload

**Files:**
- Modify: `apps/backend/app/controllers/api/v1/attachments_controller.rb`
- Modify: `apps/backend/app/controllers/api/v1/meetings_controller.rb`
- Modify: `apps/backend/spec/requests/api/v1/meeting_attachments_spec.rb`
- Modify: `apps/backend/spec/requests/api/v1/meetings_spec.rb`

**Interfaces:**
- Consumes: `Meetings::RemoveMeetingAttachment` (Task 4), `attachment_json` (Task 5).
- Produces:
  - `GET /api/v1/meetings/:meeting_id/attachments/:id/download` → `200` with the raw file bytes, `Content-Disposition: attachment; filename="<original>"`, `Content-Type` = the blob's content type. `404` when the attachment is not on a meeting the user owns; `401` unauthenticated.
  - `DELETE /api/v1/meetings/:meeting_id/attachments/:id` → `204` no body; the attachment and its blob are gone. `404` when not owned; `401` unauthenticated.
  - `GET /api/v1/meetings/:id` JSON gains `"attachments_count": Integer`.

- [ ] **Step 1: Add the failing download + destroy request specs**

Append to `apps/backend/spec/requests/api/v1/meeting_attachments_spec.rb`, inside the top-level `describe` block:

```ruby
  describe "GET /api/v1/meetings/:meeting_id/attachments/:id/download" do
    it "streams the file with its original filename and content type" do
      attachment = create_attachment(filename: "minutes.txt")

      get "/api/v1/meetings/#{meeting.id}/attachments/#{attachment.id}/download",
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("data")
      expect(response.content_type).to start_with("text/plain")
      expect(response.headers["Content-Disposition"]).to include("minutes.txt")
    end

    it "returns 404 for an attachment on another user's meeting" do
      foreign_meeting = other_user.meetings.create!(title: "Not mine", starts_at: 1.day.from_now)
      foreign = create_attachment(target: foreign_meeting)

      get "/api/v1/meetings/#{foreign_meeting.id}/attachments/#{foreign.id}/download",
          headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "rejects unauthenticated requests" do
      attachment = create_attachment

      get "/api/v1/meetings/#{meeting.id}/attachments/#{attachment.id}/download"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/meetings/:meeting_id/attachments/:id" do
    it "removes the attachment and returns 204" do
      attachment = create_attachment

      expect do
        delete "/api/v1/meetings/#{meeting.id}/attachments/#{attachment.id}",
               headers: auth_headers
      end.to change { meeting.meeting_attachments.count }.by(-1)

      expect(response).to have_http_status(:no_content)

      get "/api/v1/meetings/#{meeting.id}/attachments", headers: auth_headers
      expect(response.parsed_body).to eq([])
    end

    it "returns 404 for an attachment on another user's meeting" do
      foreign_meeting = other_user.meetings.create!(title: "Not mine", starts_at: 1.day.from_now)
      foreign = create_attachment(target: foreign_meeting)

      delete "/api/v1/meetings/#{foreign_meeting.id}/attachments/#{foreign.id}",
             headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(MeetingAttachment.exists?(foreign.id)).to be(true)
    end

    it "rejects unauthenticated requests" do
      attachment = create_attachment

      delete "/api/v1/meetings/#{meeting.id}/attachments/#{attachment.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "deleting the parent meeting" do
    it "removes its attachments" do
      create_attachment
      create_attachment(filename: "second.txt")

      expect { meeting.destroy }.to change(MeetingAttachment, :count).by(-2)
    end
  end
```

- [ ] **Step 2: Run to verify the new examples fail**

Run: `cd apps/backend && bin/rspec spec/requests/api/v1/meeting_attachments_spec.rb`
Expected: the download/destroy groups FAIL (`AbstractController::ActionNotFound` or routing error); the "deleting the parent meeting" example should already PASS (Task 1's `dependent: :destroy`). Index/create still PASS.

- [ ] **Step 3: Add `download` and `destroy` to the controller**

In `apps/backend/app/controllers/api/v1/attachments_controller.rb`, add these actions after `create` (before `private`):

```ruby
      # GET /api/v1/meetings/:meeting_id/attachments/:id/download
      def download
        attachment = @meeting.meeting_attachments.find_by(id: params[:id])
        return render json: { error: "Not found" }, status: :not_found unless attachment

        blob = attachment.file
        send_data blob.download,
                  filename: blob.filename.to_s,
                  type: blob.content_type,
                  disposition: "attachment"
      end

      # DELETE /api/v1/meetings/:meeting_id/attachments/:id
      def destroy
        result = Meetings::RemoveMeetingAttachment.call(meeting: @meeting, id: params[:id])
        return render json: { error: "Not found" }, status: :not_found if result.failure?

        head :no_content
      end
```

- [ ] **Step 4: Run the request spec to verify it passes**

Run: `cd apps/backend && bin/rspec spec/requests/api/v1/meeting_attachments_spec.rb`
Expected: PASS (all groups).

- [ ] **Step 5: Add the failing `attachments_count` example**

In `apps/backend/spec/requests/api/v1/meetings_spec.rb`, inside `describe "GET /api/v1/meetings/:id"`, add:

```ruby
    it "includes an accurate attachments_count" do
      meeting = user.meetings.create!(title: "Planning", starts_at: 2.days.from_now)
      2.times do |i|
        a = meeting.meeting_attachments.build
        a.file.attach(io: StringIO.new("x"), filename: "f#{i}.txt", content_type: "text/plain")
        a.save!
      end

      get "/api/v1/meetings/#{meeting.id}", headers: auth_headers

      expect(response.parsed_body["attachments_count"]).to eq(2)
    end
```

- [ ] **Step 6: Run it to verify it fails**

Run: `cd apps/backend && bin/rspec spec/requests/api/v1/meetings_spec.rb`
Expected: FAIL — `attachments_count` is `nil`.

- [ ] **Step 7: Add `attachments_count` to `meeting_json`**

In `apps/backend/app/controllers/api/v1/meetings_controller.rb`, in the `meeting_json` hash, add:

```ruby
          attachments_count: meeting.meeting_attachments.count,
```

- [ ] **Step 8: Run it to verify it passes**

Run: `cd apps/backend && bin/rspec spec/requests/api/v1/meetings_spec.rb`
Expected: PASS.

- [ ] **Step 9: Run the full backend suite + lint**

Run: `npm test && npm run lint:backend`
Expected: green.

- [ ] **Step 10: Commit**

```bash
git add apps/backend/app/controllers/api/v1 apps/backend/spec/requests/api/v1
git commit -m "feat: add attachment download/delete and meeting attachments_count"
```

---

# Phase C — Frontend

> Branch: `feat/meeting-attachments-ui` off the merged Phase B tip. Deliverable: Task 7 with the E2E spec green. Merge before Phase D.

### Definition of Done — Phase C

- [ ] Task 7 complete, each step committed.
- [ ] `apiFetch` sends a `FormData` body without a `Content-Type` header and without `JSON.stringify`; JSON requests behave exactly as before; `API_URL` is exported.
- [ ] `src/lib/meetings.ts` exports `MeetingAttachment` / `ProcessingStatus` types, `MAX_ATTACHMENT_BYTES`, `ALLOWED_ATTACHMENT_TYPES`, `fetchAttachments`, `uploadAttachment`, `deleteAttachment`, `downloadAttachment`, `formatFileSize`; `Meeting` type has `attachments_count`.
- [ ] `/meetings/[id]` renders `MeetingAttachments` (upload control, list with filename/size/type/date/status badge/download/delete, empty state, busy state, inline success + error).
- [ ] List re-fetches after a successful upload and after a delete.
- [ ] `npm run typecheck` — green.
- [ ] `npm run lint:frontend` — green.
- [ ] `npm run test:e2e` — full suite green, including the new `e2e/meeting-attachments.spec.ts` (empty state → upload → "Pending" row → delete → gone); `auth.spec.ts` and `meetings.spec.ts` unaffected.
- [ ] UI built with HeroUI v3 + Tailwind only; upload input has accessible name "Upload file"; delete flows through a confirm dialog.
- [ ] Branch merged to `main`.

> Screenshots and the `ui-ux-pro-max` pass are Phase D, not a Phase C gate.

## Task 7: Frontend — `Attachments` section on the meeting detail page

**Files:**
- Modify: `apps/frontend/src/lib/api.ts`
- Modify: `apps/frontend/src/lib/meetings.ts`
- Create: `apps/frontend/src/app/meetings/[id]/MeetingAttachments.tsx`
- Modify: `apps/frontend/src/app/meetings/[id]/page.tsx`
- Modify: `e2e/support/helpers.ts`
- Create: `e2e/support/fixtures/sample.txt`
- Test: `e2e/meeting-attachments.spec.ts`

**Interfaces:**
- Consumes: the attachments API (Tasks 5–6).
- Produces (from `src/lib/meetings.ts`):
  - `type ProcessingStatus = "pending" | "processed" | "failed"`
  - `type MeetingAttachment = { id: number; meeting_id: number; filename: string; byte_size: number; content_type: string; processing_status: ProcessingStatus; processed_at: string | null; created_at: string; download_url: string }`
  - `Meeting` type gains `attachments_count: number`
  - `MAX_ATTACHMENT_BYTES: number` (25 MB), `ALLOWED_ATTACHMENT_TYPES: string[]`
  - `fetchAttachments(meetingId: number | string, token: string | null): Promise<MeetingAttachment[]>`
  - `uploadAttachment(meetingId: number | string, file: File, token: string | null): Promise<MeetingAttachment>`
  - `deleteAttachment(meetingId: number | string, id: number, token: string | null): Promise<void>`
  - `downloadAttachment(attachment: MeetingAttachment, token: string | null): Promise<void>` (fetches with auth, triggers a browser download)
  - `formatFileSize(bytes: number): string`

**Note before starting:** read `apps/frontend/HEROUI_AGENTS.md` and the file-input / dialog / badge sections of the HeroUI v3 docs, and skim `apps/frontend/node_modules/next/dist/docs/` for any App Router constraint relevant to client components. The code blocks below assume a plain accessible `<input type="file">` plus HeroUI `Button`; adjust component choices to whatever `HEROUI_AGENTS.md` prescribes, keeping the same DOM roles/labels the E2E spec relies on ("Upload file" input, "Delete" button, a confirm dialog with a "Delete" confirm action, "Pending" badge text).

- [ ] **Step 1: Write the failing E2E spec**

Create `e2e/support/fixtures/sample.txt`:

```
E2E attachment fixture.
```

Add to `e2e/support/helpers.ts` (append; do not change existing exports):

```ts
/** Create a meeting through the UI and land on its detail page. */
export async function createMeetingViaUi(
  page: Page,
  { title, startsAt = "2026-12-01T10:00" }: { title: string; startsAt?: string },
): Promise<void> {
  await page.getByRole("link", { name: "New meeting" }).click();
  await page.getByLabel("Title").fill(title);
  await page.getByLabel("Starts at").fill(startsAt);
  await page.getByRole("button", { name: "Create meeting" }).click();
  await expect(page).toHaveURL(/\/meetings\/\d+$/);
}
```

Create `e2e/meeting-attachments.spec.ts`:

```ts
import path from "node:path";
import { expect, test } from "@playwright/test";
import { createMeetingViaUi, registerViaUi, uniqueEmail } from "./support/helpers";

const FIXTURE = path.join(__dirname, "support/fixtures/sample.txt");

test.describe("Meeting attachments", () => {
  test("shows an empty state, then an uploaded file, then removes it", async ({ page }) => {
    await registerViaUi(page, uniqueEmail());
    await createMeetingViaUi(page, { title: `Attach test ${Math.random().toString(36).slice(2, 8)}` });

    // Empty state.
    await expect(page.getByText("No files attached yet")).toBeVisible();

    // Upload.
    await page.getByLabel("Upload file").setInputFiles(FIXTURE);

    const row = page.getByRole("listitem").filter({ hasText: "sample.txt" });
    await expect(row).toBeVisible();
    await expect(row.getByText("Pending")).toBeVisible();

    // Delete (through the confirm dialog).
    await row.getByRole("button", { name: "Delete" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Delete" }).click();

    await expect(page.getByText("sample.txt")).toHaveCount(0);
    await expect(page.getByText("No files attached yet")).toBeVisible();
  });
});
```

- [ ] **Step 2: Run the E2E spec to verify it fails**

Run: `npm run test:e2e -- meeting-attachments`
Expected: FAIL — "No files attached yet" never appears (the section does not exist yet).

- [ ] **Step 3: Add `FormData` support to `apiFetch`**

In `apps/frontend/src/lib/api.ts`:

- Change `const API_URL = ...` to `export const API_URL = ...`.
- Replace the header/body construction in `apiFetch` with:

```ts
  const isFormData = body instanceof FormData;

  const headers: Record<string, string> = {};
  if (!isFormData) {
    headers["Content-Type"] = "application/json";
  }
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${API_URL}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : isFormData ? body : JSON.stringify(body),
  });
```

Leave the response parsing and `ApiError` handling exactly as they are. `apiFetch<void>` for a `204` response returns `null` (already handled: non-JSON → `data = null`).

- [ ] **Step 4: Add attachment types, constants, and helpers to `src/lib/meetings.ts`**

Add the `attachments_count` field to the `Meeting` type:

```ts
export type Meeting = {
  id: number;
  title: string;
  description: string | null;
  starts_at: string;
  attachments_count: number;
};
```

Append:

```ts
import { API_URL } from "@/lib/api";

export type ProcessingStatus = "pending" | "processed" | "failed";

export type MeetingAttachment = {
  id: number;
  meeting_id: number;
  filename: string;
  byte_size: number;
  content_type: string;
  processing_status: ProcessingStatus;
  processed_at: string | null;
  created_at: string;
  download_url: string;
};

/** Mirrors the backend limit (MeetingAttachment::MAX_FILE_SIZE). */
export const MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024;

/** Mirrors the backend allowlist (MeetingAttachment::ALLOWED_CONTENT_TYPES). */
export const ALLOWED_ATTACHMENT_TYPES = [
  "application/pdf",
  "text/plain",
  "image/png",
  "image/jpeg",
  "image/gif",
  "image/webp",
  "audio/mpeg",
  "audio/wav",
  "audio/mp4",
  "video/mp4",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
];

export function fetchAttachments(
  meetingId: number | string,
  token: string | null,
): Promise<MeetingAttachment[]> {
  return apiFetch<MeetingAttachment[]>(`/meetings/${meetingId}/attachments`, { token });
}

export function uploadAttachment(
  meetingId: number | string,
  file: File,
  token: string | null,
): Promise<MeetingAttachment> {
  const form = new FormData();
  form.append("attachment[file]", file);
  return apiFetch<MeetingAttachment>(`/meetings/${meetingId}/attachments`, {
    method: "POST",
    body: form,
    token,
  });
}

export function deleteAttachment(
  meetingId: number | string,
  id: number,
  token: string | null,
): Promise<void> {
  return apiFetch<void>(`/meetings/${meetingId}/attachments/${id}`, {
    method: "DELETE",
    token,
  }).then(() => undefined);
}

/** Fetch the blob with the auth header and hand it to the browser as a download. */
export async function downloadAttachment(
  attachment: MeetingAttachment,
  token: string | null,
): Promise<void> {
  const response = await fetch(`${API_URL}${attachment.download_url}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = attachment.filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB"];
  let size = bytes / 1024;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  return `${size.toFixed(1)} ${units[unitIndex]}`;
}
```

If `apiFetch<void>` trips the generic constraint, type the call as `apiFetch<null>` and keep the `.then(() => undefined)`.

- [ ] **Step 5: Fix the now-broken `Meeting` construction sites**

`attachments_count` is required on `Meeting`. Search the frontend for object literals typed as `Meeting` / `NewMeeting`:

Run: `cd apps/frontend && npx tsc --noEmit`

Expected failures and fixes:
- `src/lib/meetings.ts` `NewMeeting` is a separate type — leave it.
- Any test/mocks — none exist.
- If `tsc` flags nothing else, the API always supplies `attachments_count`, so no runtime change is needed. If it flags a literal, add `attachments_count: 0` there.

- [ ] **Step 6: Build the `MeetingAttachments` component**

Create `apps/frontend/src/app/meetings/[id]/MeetingAttachments.tsx`:

```tsx
"use client";

import { Alert, Button, Chip, Spinner, Typography } from "@heroui/react";
import { useEffect, useRef, useState } from "react";
import { ApiError } from "@/lib/api";
import { getToken } from "@/lib/token";
import {
  ALLOWED_ATTACHMENT_TYPES,
  MAX_ATTACHMENT_BYTES,
  deleteAttachment,
  downloadAttachment,
  fetchAttachments,
  formatFileSize,
  formatMeetingDate,
  type MeetingAttachment,
  type ProcessingStatus,
} from "@/lib/meetings";

const STATUS_LABEL: Record<ProcessingStatus, string> = {
  pending: "Pending",
  processed: "Processed",
  failed: "Failed",
};

const STATUS_COLOR: Record<ProcessingStatus, "warning" | "success" | "danger"> = {
  pending: "warning",
  processed: "success",
  failed: "danger",
};

export function MeetingAttachments({ meetingId }: { meetingId: number }) {
  const [attachments, setAttachments] = useState<MeetingAttachment[] | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<MeetingAttachment | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    fetchAttachments(meetingId, getToken()).then(setAttachments);
  }, [meetingId]);

  async function reload() {
    setAttachments(await fetchAttachments(meetingId, getToken()));
  }

  async function handleFile(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;

    setError(null);
    setNotice(null);

    if (file.size === 0) {
      setError("That file is empty.");
      return;
    }
    if (file.size > MAX_ATTACHMENT_BYTES) {
      setError("That file is larger than the 25 MB limit.");
      return;
    }
    if (file.type && !ALLOWED_ATTACHMENT_TYPES.includes(file.type)) {
      setError(`Files of type ${file.type} are not supported.`);
      return;
    }

    setIsUploading(true);
    try {
      const { uploadAttachment } = await import("@/lib/meetings");
      await uploadAttachment(meetingId, file, getToken());
      await reload();
      setNotice(`Uploaded ${file.name}.`);
    } catch (err) {
      setError(
        err instanceof ApiError
          ? err.errors[0] ?? err.message
          : "Upload failed. Please try again.",
      );
    } finally {
      setIsUploading(false);
    }
  }

  async function confirmDelete() {
    if (!pendingDelete) return;
    const target = pendingDelete;
    setPendingDelete(null);
    setError(null);
    setNotice(null);
    try {
      await deleteAttachment(meetingId, target.id, getToken());
      await reload();
      setNotice(`Removed ${target.filename}.`);
    } catch {
      setError("Could not remove that file. Please try again.");
    }
  }

  return (
    <section className="flex flex-col gap-4" aria-labelledby="attachments-heading">
      <Typography id="attachments-heading" type="h4">
        Files
      </Typography>

      <div className="flex flex-col gap-1">
        <label className="text-sm font-medium" htmlFor="attachment-input">
          Upload file
        </label>
        <input
          ref={inputRef}
          id="attachment-input"
          type="file"
          aria-label="Upload file"
          disabled={isUploading}
          onChange={handleFile}
          className="text-sm"
        />
        {isUploading && (
          <span className="flex items-center gap-2 text-sm">
            <Spinner size="sm" /> Uploading…
          </span>
        )}
      </div>

      {error && (
        <Alert status="danger">
          <Alert.Indicator />
          <Alert.Content>
            <Alert.Title>Upload problem</Alert.Title>
            <Alert.Description>{error}</Alert.Description>
          </Alert.Content>
        </Alert>
      )}
      {notice && (
        <Alert status="success">
          <Alert.Indicator />
          <Alert.Content>
            <Alert.Description>{notice}</Alert.Description>
          </Alert.Content>
        </Alert>
      )}

      {attachments === null && (
        <div className="flex items-center gap-2">
          <Spinner size="sm" />
          <Typography color="muted">Loading files…</Typography>
        </div>
      )}

      {attachments !== null && attachments.length === 0 && (
        <Typography color="muted">No files attached yet.</Typography>
      )}

      {attachments !== null && attachments.length > 0 && (
        <ul className="divide-border divide-y rounded-lg border">
          {attachments.map((attachment) => (
            <li
              key={attachment.id}
              className="flex flex-wrap items-center justify-between gap-3 p-3"
            >
              <div className="min-w-0">
                <p className="truncate font-medium">{attachment.filename}</p>
                <p className="text-default-500 text-xs">
                  {formatFileSize(attachment.byte_size)} · {attachment.content_type} ·{" "}
                  {formatMeetingDate(attachment.created_at)}
                </p>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <Chip color={STATUS_COLOR[attachment.processing_status]} size="sm">
                  {STATUS_LABEL[attachment.processing_status]}
                </Chip>
                <Button
                  size="sm"
                  variant="secondary"
                  onPress={() => downloadAttachment(attachment, getToken())}
                >
                  Download
                </Button>
                <Button
                  size="sm"
                  variant="danger"
                  onPress={() => setPendingDelete(attachment)}
                >
                  Delete
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {pendingDelete && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Confirm delete"
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
        >
          <div className="bg-background flex max-w-sm flex-col gap-4 rounded-xl border p-6">
            <Typography type="h5">Delete this file?</Typography>
            <Typography color="muted" type="body-sm">
              “{pendingDelete.filename}” will be permanently removed from this meeting.
            </Typography>
            <div className="flex justify-end gap-2">
              <Button variant="secondary" onPress={() => setPendingDelete(null)}>
                Cancel
              </Button>
              <Button variant="danger" onPress={confirmDelete}>
                Delete
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
```

> If `HEROUI_AGENTS.md` provides a real `Modal`/`Dialog` and file-field component, use them instead of the hand-rolled `role="dialog"` and bare `<input>` — but keep: an input reachable by the accessible name "Upload file", a per-row "Delete" button, a dialog containing a confirming "Delete" button, and visible "Pending"/"Processed"/"Failed" text.

- [ ] **Step 7: Wire the component into the detail page**

In `apps/frontend/src/app/meetings/[id]/page.tsx`:

- Add the import: `import { MeetingAttachments } from "./MeetingAttachments";`
- In the `return`, the `state.status === "not-found"` ternary currently renders either the "not found" message or the `<Card>`. Wrap the ready branch so the card and the attachments section render together:

```tsx
      {state.status === "not-found" ? (
        <Typography color="muted">This meeting could not be found.</Typography>
      ) : (
        <>
          <Card>
            {/* …unchanged card content… */}
          </Card>
          <MeetingAttachments meetingId={state.meeting.id} />
        </>
      )}
```

- [ ] **Step 8: Typecheck and lint the frontend**

Run: `npm run typecheck && npm run lint:frontend`
Expected: green. Fix any type errors (most likely a HeroUI `Chip` `color` union or `Button` `variant` name — align with `HEROUI_AGENTS.md`).

- [ ] **Step 9: Run the E2E spec to verify it passes**

Run: `npm run test:e2e -- meeting-attachments`
Expected: PASS. If the delete-dialog selectors don't match your final HeroUI dialog, adjust the spec's `getByRole("dialog")` / button-name lookups to the real accessible names (keep them meaningful).

- [ ] **Step 10: Run the whole E2E suite**

Run: `npm run test:e2e`
Expected: PASS — the existing `auth.spec.ts` and `meetings.spec.ts` are unaffected.

- [ ] **Step 11: Commit**

```bash
git add apps/frontend/src/lib/api.ts apps/frontend/src/lib/meetings.ts "apps/frontend/src/app/meetings/[id]" e2e/meeting-attachments.spec.ts e2e/support
git commit -m "feat: add meeting attachments UI to the detail page"
```

---

# Phase D — Review + docs

> Branch: `feat/meeting-attachments-docs` off the merged Phase C tip. Deliverable: Tasks 8–10 — UI/UX review applied, docs + memory updated, full suite green, PR opened.

### Definition of Done — Phase D

- [ ] Tasks 8–10 complete, each step committed.
- [ ] `screenshots/` contains the six meeting-detail states listed in Task 8 Step 2 (empty, list, uploading, error, mobile, delete-dialog).
- [ ] The `ui-ux-pro-max` skill has been run against the attachments UI and every finding is fixed or explicitly noted as won't-fix in the PR.
- [ ] `CLAUDE.md` (root), `apps/backend/CLAUDE.md`, `apps/frontend/CLAUDE.md` updated: new routes, Active Storage enabled, `MeetingAttachment` + operations + job seam, `apiFetch` FormData, detail-page attachments UI.
- [ ] Memory file `meeting-attachments.md` created and `MEMORY.md` pointer added.
- [ ] Clean-state full run all green: `npm test`, `npm run lint`, `npm run typecheck`, `npm run build`, `npm run test:e2e`.
- [ ] Spec self-review done: every user story 1–32 in `docs/specs/meeting-file-upload/spec.md` maps to shipped behaviour or documented out-of-scope.
- [ ] PR opened against `main` linking the spec + plan, listing endpoints, noting Active Storage, with screenshots attached, and the `🤖 Generated with…` trailer.
- [ ] Code review requested (`superpowers:requesting-code-review` or `/code-review high`).

## Task 8: UI/UX review gate + screenshots

**Files:** none (review artifacts only) — screenshots into `screenshots/` at the repo root.

- [ ] **Step 1: Boot the app**

Check whether the stack is already up (probe `http://localhost:3000` and `http://localhost:3001/up`). If not:

```bash
docker compose up -d
npm run dev
```

- [ ] **Step 2: Capture the states**

Using `/run` or a throwaway Playwright script, log in, create a meeting, open it, and screenshot the meeting detail page into `screenshots/`:
- `meeting-attachments-empty.png` — no attachments
- `meeting-attachments-list.png` — after uploading a file (shows the row + "Pending" chip)
- `meeting-attachments-uploading.png` — during an upload (busy state)
- `meeting-attachments-error.png` — after a rejected upload (e.g. a `.zip`)
- `meeting-attachments-mobile.png` — the list at a 390px-wide viewport
- `meeting-attachments-delete-dialog.png` — the delete confirmation open

- [ ] **Step 3: Run the `ui-ux-pro-max` skill**

Invoke the `ui-ux-pro-max` skill against the meeting detail page / `MeetingAttachments.tsx`. Apply its fixes (spacing, contrast, focus states, the status chip being label-not-colour-only, touch target sizes, dialog focus trap). Re-screenshot anything you change.

- [ ] **Step 4: Re-run the frontend gates**

Run: `npm run typecheck && npm run lint:frontend && npm run test:e2e`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add apps/frontend screenshots
git commit -m "refactor: apply UI/UX review feedback to meeting attachments"
```

(If the review produced no code changes, skip the commit and note that in the PR.)

---

## Task 9: Docs + memory

**Files:**
- Modify: `CLAUDE.md`
- Modify: `apps/backend/CLAUDE.md`
- Modify: `apps/frontend/CLAUDE.md`
- Create: `/home/dandy/.claude/projects/-home-dandy-projects-meetings-app/memory/meeting-attachments.md`
- Modify: `/home/dandy/.claude/projects/-home-dandy-projects-meetings-app/memory/MEMORY.md`

- [ ] **Step 1: Root `CLAUDE.md`**

- In "Backend at a glance", extend the routes list with:
  `GET/POST /api/v1/meetings/:meeting_id/attachments`, `GET .../:id/download`, `DELETE .../:id` (all scoped to `current_user`).
- Note that Active Storage is now enabled (disk service; cloud is a future config-only change).
- In "Frontend at a glance", note the meeting detail page now has an attachments section.

- [ ] **Step 2: `apps/backend/CLAUDE.md`**

- Add the four attachment routes to the Architecture routes list.
- Under the module-split section, add: `MeetingAttachment` (host model, `has_one_attached :file`, `processing_status` enum); attachment writes go through `Meetings::AttachMeetingFile` / `Meetings::RemoveMeetingAttachment` (`Cqrs::Command`) and `Meetings::ListMeetingAttachments` (`Cqrs::Query`) in `app/operations/meetings/` on the **host** app.
- Note `ProcessMeetingAttachmentJob` is a placeholder seam for a future processing spec.
- Note Active Storage is enabled; `config/storage.yml` has `test` + `local` disk services; test env uses `config.active_job.queue_adapter = :test`.
- Under Testing, add `spec/operations/` and `spec/jobs/` to the layout list.

- [ ] **Step 3: `apps/frontend/CLAUDE.md`**

- In Architecture, note `apiFetch` now accepts a `FormData` body (skips `Content-Type` + `JSON.stringify`), and `API_URL` is exported.
- Note `src/lib/meetings.ts` gained `MeetingAttachment` + attachment helpers and `formatFileSize`; `Meeting` now has `attachments_count`.
- Note `/meetings/[id]` renders `MeetingAttachments` (upload, list, download, delete-with-confirm).

- [ ] **Step 4: Write the memory file**

Create `meeting-attachments.md`:

```markdown
---
name: meeting-attachments
description: Meetings have file attachments via Active Storage; MeetingAttachment host model carries a pending/processed/failed processing_status
metadata:
  type: project
---

Meetings can have file attachments (added 2026-08-30, spec
`docs/specs/meeting-file-upload/spec.md`, plan
`docs/plans/2026-08-30-meeting-file-upload.md`).

- Active Storage is enabled (disk service; cloud storage deliberately deferred).
- `MeetingAttachment` — host model, `belongs_to :meeting`, `has_one_attached :file`,
  `processing_status` enum (`pending`/`processed`/`failed`, default `pending`) +
  `processed_at`. `Meeting has_many :meeting_attachments, dependent: :destroy`.
- Constants `MeetingAttachment::MAX_FILE_SIZE` (25 MB) and `ALLOWED_CONTENT_TYPES`
  are backend-authoritative; the frontend mirrors them in `src/lib/meetings.ts`
  (`MAX_ATTACHMENT_BYTES`, `ALLOWED_ATTACHMENT_TYPES`) for pre-upload checks only.
- API: `GET/POST /api/v1/meetings/:meeting_id/attachments`,
  `GET .../:id/download` (send_data), `DELETE .../:id`. Upload field
  `attachment[file]`, multipart. `download_url` in payloads is relative.
- Writes go through host-app operations in `app/operations/meetings/`
  (`AttachMeetingFile`, `RemoveMeetingAttachment`, `ListMeetingAttachments`) —
  see [[backend-cqrs-engine-split]].
- `ProcessMeetingAttachmentJob` is a PLACEHOLDER — a successful upload enqueues
  exactly one; its body just marks the attachment `processed`. Real processing is
  a future spec. Test env uses the `:test` queue adapter.
- Frontend: `MeetingAttachments` component on `/meetings/[id]`; `apiFetch` now
  supports `FormData` bodies.
```

- [ ] **Step 5: Add the `MEMORY.md` pointer**

Append to `MEMORY.md`:

```
- [Meeting attachments](meeting-attachments.md) — meetings have Active Storage file attachments with a pending/processed/failed processing_status
```

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md apps/backend/CLAUDE.md apps/frontend/CLAUDE.md
git commit -m "docs: document meeting attachments feature"
```

(The memory directory lives outside the repo — it is not part of this commit.)

---

## Task 10: Full-suite verification + PR

**Files:** none.

- [ ] **Step 1: Run every gate from a clean state**

```bash
docker compose up -d
npm test
npm run lint
npm run typecheck
npm run build
npm run test:e2e
```

Expected: all green. If `maintain_test_schema!` complains about pending migrations, run `cd apps/backend && RAILS_ENV=test bin/rails db:prepare` and re-run.

- [ ] **Step 2: Self-review the diff against the spec**

Walk `docs/specs/meeting-file-upload/spec.md` user stories 1–32 and confirm each maps to shipped behaviour or is explicitly out of scope. In particular re-check: 20/21/22 (ownership + auth + 404), 29 (meeting delete cascades), 30 (download filename/type), 31 (same-name files), 32 (empty file rejected).

- [ ] **Step 3: Push and open the PR**

Each phase (A–D) opens its own PR against `main` as it completes; this step is the
Phase D PR. If phases were instead built as one stacked branch, push that here.

```bash
git push -u origin feat/meeting-attachments-docs
gh pr create --fill --base main
```

PR body: link the spec and plan, list the new endpoints, note Active Storage is now enabled, and attach the `screenshots/` images. End the body with:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

- [ ] **Step 4: Request code review**

Use the `requesting-code-review` / `superpowers:requesting-code-review` skill (or `/code-review high`) against the branch before merge.

---

## Self-Review (performed while writing this plan)

**1. Spec coverage**

| Spec item | Task(s) |
|---|---|
| Attach one / many files (stories 1, 2, 31) | 3, 5 |
| List on the detail page (3, 4, 5, 6, 7) | 4, 5, 7 |
| Download (8, 30) | 6, 7 |
| Delete + confirm (9, 10) | 6, 7 |
| Upload busy / success / error UI (11, 12, 13, 14) | 7 |
| Processing status shown + lifecycle (15, 16, 17, 27) | 1, 2, 5, 7 |
| Max size / type allowlist (18, 19, 32) | 1, 3, 5, 7 |
| Non-owner blocked / 401 / 404 (20, 21, 22) | 5, 6 |
| Past or future meeting (23) | 3 (no date coupling — inherent) |
| Mobile + a11y (24, 25, 26) | 7, 8 |
| `attachments_count` on meeting payload (28) | 6 |
| Meeting delete cascades (29) | 1 (association), 6 (test) |
| Active Storage enablement | 1 |
| CQRS operation structure | 3, 4 |
| `apiFetch` FormData + `meetings.ts` helpers | 7 |
| Docs + memory | 9 |
| Both suites + lint green | every task + 10 |

No gaps.

**2. Placeholder scan** — no "TBD"/"add error handling"/"similar to Task N"; every code step carries real code. The one hand-wave (exact HeroUI component names) is explicitly delegated to `HEROUI_AGENTS.md` with the invariant DOM contract spelled out, because the library's current API is not in scope to reproduce here.

**3. Type consistency** — `MeetingAttachment` JSON shape is identical in the spec, the backend `attachment_json` (Task 5), the request-spec assertions (Task 5), and the TS type (Task 7). Operation names (`Meetings::AttachMeetingFile`, `Meetings::RemoveMeetingAttachment`, `Meetings::ListMeetingAttachments`) are used identically in Tasks 3–6. Constant names: backend `MeetingAttachment::MAX_FILE_SIZE` / `ALLOWED_CONTENT_TYPES`; frontend `MAX_ATTACHMENT_BYTES` / `ALLOWED_ATTACHMENT_TYPES` — deliberately different names (different units/language), same values, cross-referenced in the memory file.

**Note on a spec deviation:** the spec's Implementation Decisions mention both `Meeting has_many_attached :files` *and* a `MeetingAttachment` model. Those overlap. This plan uses only `MeetingAttachment has_one_attached :file` + `Meeting has_many :meeting_attachments`, because the spec's own rationale ("a future processing feature needs a stable row to update") requires the join model to own the attachment. Flagged here for the reviewer.
