# Implementation plans

Implementation plans (from `/superpowers:writing-plans` or written by hand) live as
local markdown under `doc/plans/`.

## Conventions

- One plan per file: `doc/plans/<feature-slug>.md`
- The plan names the spec it implements (`doc/specs/<feature-slug>/spec.md`) in its
  header, and argues every decision from that spec
- All content in English (see memory `english-only-project-content`)

## Structure: phases

Every plan is divided into **phases**. A phase is a unit of work that can be handed
to a single subagent and completed end-to-end without coordinating with any other
phase that is running.

- Each phase is **independent**: it produces a working, independently testable
  deliverable (its own suite green), and a subagent can own it in isolation.
- Dependencies between phases flow in one direction only — phase N+1 builds on
  phase N once phase N is merged. No phase depends on a sibling that is in flight
  at the same time.
- A phase groups one or more of the plan's tasks. Tasks keep their bite-sized
  TDD steps (write failing test → run → implement → run → commit).
- The plan includes a phase map (phase → tasks → deliverable → what it depends on)
  so phases can be dispatched to subagents with `superpowers:subagent-driven-development`.

## Publishing to GitHub

The `/plan-to-github` skill (`.claude/skills/plan-to-github/`) turns a plan into
GitHub tracking objects: one **milestone per phase**, one **issue per task**
(title from the `## Task ...` heading, body = the task's full section), each added
to the Projects v2 board **"Meetings App — Delivery"**
(<https://github.com/users/DandyCV/projects/2>, id `PVT_kwHOAvyPJ84Bh8Mv`). It is
idempotent by title — re-run after adding tasks to create only the new ones.

### Definition of Done per phase

Every phase spells out its own **completion criteria** — an explicit checklist a
subagent (or reviewer) can tick off to confirm the phase is finished. Each item is
objectively verifiable, not a judgement call. Cover, as applicable:

- every task in the phase complete, each with its TDD cycle done and committed
- the named test suite(s) run and green (give the exact commands)
- lint / typecheck / build green (exact commands)
- the phase's user-visible or API-visible behaviour demonstrably works
- docs / memory touched by the phase updated
- no unrelated changes; branch merged (or PR opened) per the phase map

A phase is not done until every box is checked.
