---
name: to-spec
description: "Turn the current conversation into a spec and publish it to the project issue tracker: no interview, just synthesis of what you've already discussed."
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user; just synthesize what you already know.

The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Check with the user that these seams match their expectations.

3. Write the spec using the template below, then publish it to the project issue tracker. Apply the `ready-for-agent` triage label - no need for additional triage.

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## Technical Constraints

The hard limits the implementation must respect — state them explicitly, with exact
values, even when they seem obvious. Cover, as applicable:

- Version floors and dependency limits (language/framework/library versions, "no new
  runtime dependencies", allowed package sources)
- Platform / environment requirements (browsers, Node/Ruby versions, CI containers)
- Architectural boundaries that must not be crossed (module/engine split, layering
  rules, "controllers never touch X directly")
- Data limits and formats (max sizes, allowed types, encodings, id formats)
- Performance / resource budgets (response-time targets, payload sizes, query counts)
- Security & auth constraints (scoping rules, what must stay private, what must never
  be logged or exposed)
- Naming, copy, and localization rules (e.g. "all repo content in English")
- Backward-compatibility requirements (existing API contracts, DB columns, routes
  that must keep working)

If a constraint is a project rule, cite where it comes from (a `CLAUDE.md` line, an
ADR, a memory).

## Testing Decisions

A list of testing decisions that were made. Include:

- A "Process: TDD" statement — implementation follows red-green-refactor, no production
  code without a failing test driving it, run via the `/tdd` skill. This clause is
  mandatory in every spec for this repo.
- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Acceptance Criteria

An explicit, numbered checklist of "done" conditions for the whole feature —
objectively verifiable, not judgement calls. This is what a reviewer ticks off to
accept the work. Each item is a concrete, checkable statement (a specific request
returns a specific status/shape; a specific UI state is reachable; a named suite is
green; a named doc is updated). Cover the happy path, every error/guard path, the
edge cases from the user stories, and the non-functional constraints above. The
implementation plan's per-phase Definition-of-Done checklists derive from this
section.

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
