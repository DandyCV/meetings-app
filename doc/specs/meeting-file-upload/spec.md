# Spec: Meeting file upload, storage, and display

Status: ready-for-agent

## Problem Statement

As a user, when I open one of my meetings I have nowhere to put the artifacts that
belong to it — an agenda, a recording, a transcript, a slide deck, notes. Today a
meeting is only a title, a start time, and a free-text description. Anything I want
to keep alongside the meeting has to live in some other tool, so the meeting record
in this app is incomplete and I cannot come back later and find the file that went
with it. I also want those files to be available for later processing (for example,
generating a transcript or summary), which is impossible while the app never
receives the file at all.

## Solution

Each meeting gains an **attachments** area. From the meeting detail page I can
upload one or more files against that meeting. Uploaded attachments are stored by
the backend and listed on the meeting detail page with their filename, size, type,
and upload time. I can download an attachment, and I can remove one I no longer
want. Every attachment carries a **processing status** (`pending` while it waits to
be processed, `processed` once processing has run, `failed` if it could not be) so
that later, processing features have a place to hook in and I can see where an
attachment is in that lifecycle. Attachments are private to me in exactly the same
way meetings already are: only the owner of the meeting can list, upload,
download, or delete its attachments.

## User Stories

1. As a meeting owner, I want to attach a file to one of my meetings, so that the
   meeting record holds everything relevant to it in one place.
2. As a meeting owner, I want to attach several files to the same meeting, so that
   I can keep the agenda, the deck, and the recording together.
3. As a meeting owner, I want to see a list of the files attached to a meeting when
   I open it, so that I know what has already been uploaded.
4. As a meeting owner, I want each attachment to show its original filename, so
   that I can tell the files apart.
5. As a meeting owner, I want each attachment to show its file size, so that I know
   what I am about to download.
6. As a meeting owner, I want each attachment to show its content type / kind, so
   that I know whether it is a document, an image, audio, or video.
7. As a meeting owner, I want each attachment to show when it was uploaded, so that
   I can find the most recent version.
8. As a meeting owner, I want to download an attachment from the meeting detail
   page, so that I can open it locally.
9. As a meeting owner, I want to delete an attachment I no longer need, so that the
   meeting stays tidy and I do not keep stale files.
10. As a meeting owner, I want a confirmation before an attachment is permanently
    deleted, so that I do not lose a file by a misclick.
11. As a meeting owner, I want to see upload progress or at least a clear busy
    state while a file uploads, so that I know the app is working and do not
    re-submit.
12. As a meeting owner, I want a clear success indication once an upload finishes,
    so that I know the file is safely stored.
13. As a meeting owner, I want a clear, human-readable error if an upload fails
    (file too large, unsupported type, network error), so that I understand what
    to do next.
14. As a meeting owner, I want the attachment list to refresh automatically after I
    upload or delete a file, so that what I see always matches reality without a
    manual reload.
15. As a meeting owner, I want each attachment to show a processing status, so that
    I can see whether follow-up processing has run against it.
16. As a meeting owner, I want a newly uploaded attachment to start in a `pending`
    processing status, so that it is queued for processing from the moment it
    lands.
17. As a meeting owner, I want the processing status to update to `processed` or
    `failed` once processing has run, so that the status stays meaningful.
18. As a meeting owner, I want to be prevented from uploading a file above a
    defined maximum size, so that I get immediate feedback instead of a slow
    failed upload.
19. As a meeting owner, I want the upload control to only accept an allowed set of
    file types, so that I do not waste time uploading something the app will
    reject.
20. As a user who is not the owner of a meeting, I want to be unable to see, list,
    download, or delete that meeting's attachments, so that my and others' files
    stay private.
21. As an unauthenticated visitor, I want every attachment endpoint to reject me,
    so that files are never exposed without a valid session.
22. As a user, I want attachment endpoints for a meeting id that does not exist (or
    is not mine) to return a not-found response, so that the app does not leak
    whether a meeting exists.
23. As a meeting owner, I want to attach a file to a meeting whether it is in the
    past or the future, so that I can add a recording after the meeting or an
    agenda before it.
24. As a mobile user, I want the upload control and attachment list to be usable on
    a small screen, so that I can manage meeting files from my phone.
25. As a keyboard and screen-reader user, I want the upload control, the download
    action, and the delete action to be reachable and clearly labelled, so that I
    can manage attachments without a mouse.
26. As a meeting owner, I want a meeting with no attachments to show a clear empty
    state rather than a blank area, so that I know uploading is possible.
27. As a developer building a processing feature later, I want a documented place
    where an attachment's processing status and processed result are recorded, so
    that I can build on top of this without reworking the schema.
28. As a developer, I want the meeting detail API response to tell me how many
    attachments a meeting has (or include them), so that the frontend can render
    the list from a single request where practical.
29. As a meeting owner, I want deleting a meeting to also remove its attachments
    and their stored blobs, so that deleted meetings do not leave orphaned files.
30. As a meeting owner, I want an attachment's download to serve the original
    filename and content type, so that the downloaded file opens correctly.
31. As a meeting owner, I want two files with the same name attached to one meeting
    to both be kept, so that I do not silently overwrite an earlier upload.
32. As a meeting owner, I want the upload to reject an empty file, so that I do not
    end up with a zero-byte attachment.

## Implementation Decisions

### Storage mechanism

- Enable **Active Storage** in the backend (currently disabled in
  `config/application.rb`). Add the Active Storage migration and `db/schema.rb`
  changes on the host app (not in an engine), consistent with the rule that
  migrations and schema stay in `apps/backend/db/`.
- Local disk service for development and test; the production service is
  configured via `config/storage.yml` and can be switched later without touching
  the model or API. Choosing a cloud provider is out of scope.
- `Meeting has_many_attached :files` (host model). The `Meeting` model stays a host
  model; no new engine.

### Attachment metadata and processing lifecycle

- Introduce a host model — `MeetingAttachment` — that wraps one Active Storage
  attachment and carries the app-level metadata the blob does not: `processing_status`
  (enum: `pending`, `processed`, `failed`, default `pending`) and a nullable
  `processed_at`. It `belongs_to :meeting`; the meeting `has_many :meeting_attachments`.
  Rationale: the processing status is domain state, not storage state, and a
  future processing feature needs a stable row to update.
- Prototype-derived state shape for an attachment as returned by the API:

  ```
  {
    id: number,
    meeting_id: number,
    filename: string,
    byte_size: number,
    content_type: string,
    processing_status: "pending" | "processed" | "failed",
    processed_at: string | null,   // ISO8601
    created_at: string             // ISO8601, upload time
    download_url: string           // relative API path
  }
  ```

- On successful upload, enqueue an Active Job (`ProcessMeetingAttachmentJob` or
  similar) that is responsible for moving the attachment out of `pending`. The job
  body itself is a no-op placeholder for now (it may simply mark the attachment
  `processed`); the real processing logic is a separate spec. The contract that
  matters here: **upload enqueues exactly one processing job for the new
  attachment.**

### API contract

New routes, all nested under a meeting and all scoped to `current_user`, all
returning 404 for an unknown or other-user meeting id, all 401 without a valid JWT:

- `GET /api/v1/meetings/:meeting_id/attachments` — list attachments for the
  meeting (array of the shape above).
- `POST /api/v1/meetings/:meeting_id/attachments` — `multipart/form-data`, single
  file field (e.g. `attachment[file]`). Returns the created attachment (201) or an
  errors array (422) for: no file, empty file, file over the max size, disallowed
  content type.
- `GET /api/v1/meetings/:meeting_id/attachments/:id/download` — streams the blob
  with the original filename and content type (redirect to or proxy of the Active
  Storage blob).
- `DELETE /api/v1/meetings/:meeting_id/attachments/:id` — removes the attachment
  and its blob; returns 204. 404 if the attachment is not on a meeting the user
  owns.

- The existing `GET /api/v1/meetings/:id` response gains an `attachments_count`
  field (and continues to be the source for the detail page's initial render). The
  list endpoint is the source of truth for the attachments themselves.
- Error shape stays the project convention: `{ error: "..." }` for 401/404,
  `{ errors: [...] }` for 422 `:unprocessable_content`.

### Validation rules (backend-authoritative, frontend-mirrored)

- Maximum file size: a single documented constant (proposed **25 MB**), enforced
  in the backend; the frontend rejects oversize files before upload as a
  convenience only.
- Allowed content types: a documented allowlist (proposed: PDF, plain text,
  common image types, common audio types, common office document types). Backend
  is authoritative.
- Reject zero-byte / missing file.

### Controller / operation structure

- New `Api::V1::AttachmentsController` (nested resource). Controllers compose
  operations and render plain hashes as JSON, per the backend conventions — no
  serializer library.
- Because uploading and deleting an attachment is a write with a rule set
  (ownership, validation, job enqueue), model it as `Cqrs::Command` operations on
  the host app (e.g. `AttachMeetingFile`, `RemoveMeetingAttachment`) returning
  `Cqrs::Result`. Listing is a `Cqrs::Query`. These live on the host app rather
  than in `cqrs`/`auth`/`users`, since attachments are a `Meeting` concern and
  `Meeting` is a host model; the CQRS classes themselves come from the `cqrs`
  engine as today.

### Frontend

- `apiFetch` in `src/lib/api.ts` is JSON-only today. Extend it (or add a sibling
  helper) to support `FormData` bodies: when the body is `FormData`, do not set
  `Content-Type` and do not `JSON.stringify`. Keep the token/error handling
  identical.
- `src/lib/meetings.ts` gains: `MeetingAttachment` type, `fetchAttachments`,
  `uploadAttachment`, `deleteAttachment`, and a `downloadAttachmentUrl` helper.
- The meeting detail page (`meetings/[id]/page.tsx`) gains an **Attachments**
  section under the meeting card: an upload control (HeroUI v3 only), a list of
  attachments (filename, size, type, uploaded-at, processing-status badge,
  download link, delete button with confirmation), an empty state, a busy state
  during upload, and inline success / error feedback. The list re-fetches after a
  successful upload or delete.
- Processing status renders as a small labelled badge with distinct styling per
  state; text label always present (not colour-only) for accessibility.
- All new UI is HeroUI v3 + Tailwind v4, matching the existing pages. Follow the
  "UI review after UI changes" rule: run the UI/UX pass and save screenshots of
  the meeting detail page (empty, with attachments, uploading, error) to
  `screenshots/` at the repo root.

### Docs

- Update root `CLAUDE.md` and `apps/backend/CLAUDE.md` route lists with the new
  attachment endpoints and the fact that Active Storage is now enabled.
- Update `apps/frontend/CLAUDE.md` with the new meeting-detail attachments UI and
  the `FormData` capability in `api.ts`.
- Note the new host models (`MeetingAttachment`) and the processing-job seam in
  `apps/backend/CLAUDE.md`; add/adjust memory where architecture memory exists.

## Technical Constraints

- **Stack floors:** Rails 8.1 / Ruby 4.0 backend, Next.js 16 / React 19 / TypeScript
  frontend, PostgreSQL 17, Node per the repo's `.nvmrc`/CI. No downgrades.
- **No new runtime gems.** Active Storage ships with Rails; enabling the engine is
  allowed. `marcel` (content-type sniffing) is already bundled. Do not add cloud
  SDKs — storage is the local disk service only (cloud is out of scope).
- **No new frontend runtime dependencies.** UI is HeroUI v3 (`@heroui/react`) +
  Tailwind v4 only (`apps/frontend/CLAUDE.md`). No upload/dropzone libraries.
- **Architectural boundaries** (`apps/backend/CLAUDE.md`, memory
  `backend-cqrs-engine-split`): attachment write logic lives in host-app
  `Cqrs::Command`/`Query` operations under `app/operations/meetings/`, never in an
  engine. Controllers only compose operations. Migrations and `db/schema.rb` stay
  in `apps/backend/db/`, never in engines.
- **Auth & scoping:** every attachment endpoint requires a valid JWT bearer token
  and is scoped to `current_user`. An unknown or other-user `meeting_id` (or
  attachment `id`) returns `404` — it must not leak whether the record exists.
  Attachment blobs must never be reachable without an authenticated, authorized
  request (no public blob URLs in payloads).
- **API compatibility:** existing routes and response shapes for
  `GET/POST /api/v1/meetings*` must keep working. `GET /api/v1/meetings/:id` may
  only gain fields (`attachments_count`), never lose or rename any.
- **Error shape:** `{ error: "..." }` for 401/404, `{ errors: [...] }` for 422
  `:unprocessable_content` (project convention).
- **Data limits:** max file size 25 MB; content-type allowlist as listed in
  Implementation Decisions; zero-byte and missing files rejected. The backend is
  authoritative; the frontend mirror is a convenience only.
- **`download_url`** in every payload is a relative path, never absolute.
- **Job adapter:** the test environment uses the `:test` Active Job adapter so the
  processing job is asserted-enqueued, not executed, in specs.
- **All repo content in English** (memory `english-only-project-content`).
- **Test discipline:** `npm test` and `npm run test:e2e` (plus `npm run lint`) green
  before done — anything touching the API contract needs both layers (memory
  `testing-discipline`).

## Testing Decisions

### Process: TDD

Implementation follows test-driven development. For every seam and every case
below: write the failing request spec / E2E scenario first, watch it fail for the
right reason, write the minimum code to make it pass, then refactor. No production
code is added without a failing test driving it. Use the `/tdd` skill to run the
red-green-refactor loop.

### What makes a good test here

Tests assert externally observable behaviour through the two established seams —
the HTTP API and the browser — never internal method calls, instance variables, or
Active Storage internals. A test says "POST a file, then GET the list and the file
is there with `processing_status: pending`", not "the model received
`files.attach`". Job behaviour is asserted at the observable edge: "after upload,
one `ProcessMeetingAttachmentJob` is enqueued for the new attachment" using the
test adapter, not by testing the job's body here.

### Seam 1 — Backend HTTP request specs

Location: `apps/backend/spec/requests/api/v1/` (new file alongside the existing
`meetings_spec.rb`, which is the prior art — same `Users::User.create!` +
`Auth::GenerateToken` setup, transactional fixtures, no FactoryBot, plain
`response.parsed_body` assertions).

Cases to cover:

- Upload a valid file → 201, response has the documented shape, `processing_status`
  is `pending`, `created_at` set.
- Upload enqueues exactly one processing job for the created attachment
  (`have_enqueued_job` / test adapter).
- List returns only the given meeting's attachments, for the owner only.
- List / upload / download / delete on another user's meeting → 404.
- List / upload / download / delete with no token → 401.
- Upload with no file / empty file / oversize file / disallowed content type →
  422 with `{ errors: [...] }`.
- Download returns the blob with the original filename and content type.
- Delete → 204, and a subsequent list no longer includes it.
- Deleting the parent meeting removes its attachments (no orphaned
  `MeetingAttachment` rows / blobs).
- Two uploads with the same filename → both listed.
- `GET /api/v1/meetings/:id` includes an accurate `attachments_count`.

If `Cqrs::Command`/`Query` operations are added, add operation specs under the
host app's `spec/` mirroring the existing `spec/auth` / `spec/users` operation
spec style.

### Seam 2 — Frontend Playwright E2E

Location: `e2e/` (new spec file; `e2e/meetings.spec.ts` and `e2e/auth.spec.ts` are
the prior art — random `e2e-…@example.com` account per test, no seeding, both apps
auto-booted).

One happy-path scenario, plus a couple of guards:

- Register / log in, create a meeting, open it, upload a small fixture file via the
  upload control, and assert the attachment appears in the list with its filename
  and a `pending` status badge.
- Delete the attachment from the UI (through the confirmation) and assert it
  disappears from the list.
- Assert the empty state shows for a meeting with no attachments.
- A small binary/text fixture file lives under `e2e/support/` (or similar) for the
  upload.

Both suites (`npm test` and `npm run test:e2e`) plus `npm run lint` must be green
before the work is considered done, per the project testing-discipline rule.

## Acceptance Criteria

Objectively verifiable "done" conditions for the whole feature. The implementation
plan's per-phase Definition-of-Done checklists derive from this list.

### Backend — storage & model

1. `bin/rails db:migrate` creates the three `active_storage_*` tables and a
   `meeting_attachments` table (`meeting_id` FK, `processing_status` string not-null
   default `"pending"`, `processed_at` datetime nullable, timestamps).
2. `MeetingAttachment` is invalid without an attached file; with an empty (0-byte)
   file; with a file larger than 25 MB; with a content type outside the allowlist.
3. A new `MeetingAttachment` has `processing_status == "pending"` and
   `processed_at == nil`.
4. Destroying a `Meeting` destroys its `MeetingAttachment` rows and purges their
   blobs (no orphans).

### Backend — API

5. `POST /api/v1/meetings/:meeting_id/attachments` with a valid `attachment[file]`
   → `201` with exactly this shape: `id, meeting_id, filename, byte_size,
   content_type, processing_status, processed_at, created_at, download_url`;
   `processing_status == "pending"`; `download_url` is
   `/api/v1/meetings/:meeting_id/attachments/:id/download`.
6. A successful upload enqueues exactly one `ProcessMeetingAttachmentJob` for the
   created attachment.
7. `POST` with no file / an empty file / a file > 25 MB / a disallowed content type
   → `422` with `{ "errors": [...] }` and no attachment persisted, no job enqueued.
8. Two uploads with the same filename to one meeting → both are stored and listed.
9. `GET /api/v1/meetings/:meeting_id/attachments` → `200` array of the shape above,
   containing only that meeting's attachments, oldest first; `[]` when none.
10. `GET .../attachments/:id/download` → `200`, body is the exact file bytes,
    `Content-Type` is the blob's type, `Content-Disposition` includes the original
    filename.
11. `DELETE .../attachments/:id` → `204`, no body; a subsequent list omits it; the
    blob is purged.
12. For every attachment endpoint: a `meeting_id`/`id` that is unknown or belongs to
    another user → `404` `{ "error": ... }`; a missing/invalid token → `401`.
13. `GET /api/v1/meetings/:id` includes `attachments_count` equal to the real count;
    all previously-present fields are unchanged.
14. `ProcessMeetingAttachmentJob#perform` moves an attachment from `pending` to
    `processed` and sets `processed_at`.

### Frontend

15. Opening a meeting with no attachments shows a visible empty state ("No files
    attached yet").
16. Selecting a valid file uploads it; on success the list shows a row with the
    filename, human-readable size, content type, upload date, and a **Pending**
    status badge (text, not colour-only); a success message appears.
17. During upload a busy state is visible and the input is disabled.
18. Selecting a file > 25 MB or of a disallowed type shows an inline human-readable
    error and does not call the API.
19. A failed upload (API `422`/network) shows an inline human-readable error.
20. Each row has a Download action that saves the original file, and a Delete
    action that opens a confirm dialog; confirming removes the row (and re-shows the
    empty state when it was the last one); cancelling leaves it.
21. The list reflects server state after every upload and delete without a manual
    reload.
22. The section is usable at a 390 px viewport; the upload control, download, and
    delete actions are keyboard-reachable and have accessible names.
23. UI uses only HeroUI v3 + Tailwind; no new dependencies.

### Cross-cutting

24. `npm test`, `npm run test:e2e`, `npm run lint`, `npm run typecheck`, and
    `npm run build` are all green.
25. `e2e/meeting-attachments.spec.ts` exercises empty state → upload → Pending row →
    delete → gone; `auth.spec.ts` and `meetings.spec.ts` still pass.
26. Root `CLAUDE.md`, `apps/backend/CLAUDE.md`, `apps/frontend/CLAUDE.md` and the
    `meeting-attachments` memory are updated to match the shipped code.
27. Screenshots of the affected meeting-detail states are saved to `screenshots/`
    and the `ui-ux-pro-max` pass has been run with findings addressed.
28. Every user story 1–32 maps to a shipped behaviour above or to an explicit
    Out-of-Scope entry.

## Out of Scope

- The actual processing of an attachment (transcription, summarisation, OCR,
  virus scanning, thumbnailing). This spec only creates the `pending` status, the
  job enqueue seam, and the status field the processing feature will update.
- Cloud / S3 storage configuration and production bucket setup. Active Storage is
  enabled with the local disk service; swapping the service is a config-only
  follow-up.
- Sharing a meeting or its attachments with other users; any collaboration model.
  Attachments inherit the current owner-only meeting scoping unchanged.
- Editing an attachment in place, versioning, or replacing a file while keeping the
  same attachment id.
- Inline preview / rendering of attachment contents (PDF viewer, image lightbox,
  audio player). The list offers download only.
- Drag-and-drop upload, paste-to-upload, and multi-file select in a single action
  (the control accepts one file per upload for now; uploading several means
  several uploads). Can be added later without an API change.
- Quotas / total-storage limits per user or per meeting.
- Adding attachments during meeting creation (`/meetings/new`); upload is only
  from the existing meeting's detail page.

## Further Notes

- Active Storage brings three tables (`active_storage_blobs`,
  `active_storage_attachments`, `active_storage_variant_records`) and a route for
  blob delivery. The CI `postgres:17` service and the e2e Rails boot both run
  migrations, so enabling it should need no CI change beyond the new migration.
- The `download_url` in the API response should be a relative path so it works
  across environments; the frontend prefixes it with the API base like other
  calls.
- Keep the max-size and allowed-types constants in one backend location and
  surface their values to the frontend (build-time constant or a small config
  endpoint) so the two never drift.
- The processing job is deliberately a thin placeholder. Give it a clear TODO and
  a spec pointer so the next feature picks it up rather than re-deriving the seam.
- Domain vocabulary used here: **meeting** (existing), **attachment** / **meeting
  attachment** (new — a file stored against a meeting), **processing status** (new
  — `pending` / `processed` / `failed` lifecycle of an attachment).
