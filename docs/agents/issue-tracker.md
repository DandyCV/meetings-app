# Issue tracker: Local Markdown

Generated specs and implementation issues for this repo live as markdown files
under `doc/specs/`.

## Conventions

- One feature per directory: `doc/specs/<feature-slug>/`
- The spec is `doc/specs/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at
  `doc/specs/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a
  single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file
- Comments and conversation history append to the bottom of the file under a
  `## Comments` heading
- All content in English (see memory `english-only-project-content`)
- Every `/to-spec` spec must include these sections, on top of the base template:
  - **Technical Constraints** — the hard limits the implementation must respect
    (version floors, dependency/platform limits, architectural boundaries, data
    limits, performance budgets, security/auth scoping, naming/copy rules,
    backward-compat requirements), with exact values and a citation when the
    constraint is an existing project rule
  - **Testing Decisions → Process: TDD** — red-green-refactor, no production code
    without a failing test; implementation runs the `/tdd` loop
  - **Acceptance Criteria** — an explicit, numbered, objectively verifiable "done"
    checklist for the whole feature; the plan's per-phase Definition-of-Done
    checklists derive from it (see `docs/agents/plans.md`)

## When a skill says "publish to the issue tracker"

Create a new file under `doc/specs/<feature-slug>/` (creating the directory if
needed). For `/to-spec`, write `doc/specs/<feature-slug>/spec.md`. There are no
labels to apply — record `Status: ready-for-agent` near the top of the file
instead.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the
feature slug directly.
