---
name: plan-to-github
description: "Use when the user wants an implementation plan in doc/plans/ turned into GitHub milestones and issues, mentions creating milestones/issues from a plan, or runs /plan-to-github."
disable-model-invocation: true
---

# plan-to-github

Turn one implementation plan (`doc/plans/<slug>.md`, phased per `docs/agents/plans.md`)
into GitHub milestones and issues for `DandyCV/meetings-app` using the `gh` CLI:

- **one milestone per phase** (`# Phase ...` heading)
- **one issue per task** (`## Task ...` heading), assigned to that phase's milestone

This creates real GitHub objects. Confirm with the user before the first write.

## Preconditions

- `gh auth status` succeeds and `gh repo view --json nameWithOwner` is the intended repo.
- The plan file exists and contains `# Phase ` and `## Task ` headings. If it has no
  phases, stop and tell the user to phase the plan first (`docs/agents/plans.md`).

## Process

1. **Pick the plan.** Use the path the user gave. Otherwise list `doc/plans/*.md`; if
   there is exactly one, use it, else ask which.

2. **Parse it.** Run the bundled parser (handles fenced code blocks, keeps each task's
   full section as its body):

   ```bash
   python3 .claude/skills/plan-to-github/parse_plan.py doc/plans/<slug>.md
   ```

   It prints JSON: `{ plan_path, phases: [ { title, body, tasks: [ { title, body } ] } ] }`.

3. **Show the plan of record and confirm.** Print a table: each phase title → its task
   titles. Ask the user to confirm before creating anything.

4. **Create/reuse milestones.** For each phase, in order:
   - List existing: `gh api "repos/{owner}/{repo}/milestones?state=all" --jq '.[].title'`.
   - If a milestone with the exact phase title exists, reuse it. Otherwise create it:

     ```bash
     gh api --method POST repos/{owner}/{repo}/milestones \
       -f title="Phase A — Storage foundation" \
       -f state=open \
       -f description="<phase.body>"
     ```

     (`gh` has no native `milestone` command — use `gh api`. Pass the phase body via a
     temp file and `--input` if it is large or has shell-hostile characters.)

5. **Create issues.** For each task in each phase:
   - Skip if an issue with the identical title already exists:
     `gh issue list --state all --search "<task.title> in:title" --json title`.
   - Otherwise create it, body from a temp file, assigned to the phase milestone:

     ```bash
     printf '%s\n' "$TASK_BODY" > "$tmp"
     gh issue create \
       --title "Task 1: Enable Active Storage + MeetingAttachment model" \
       --body-file "$tmp" \
       --milestone "Phase A — Storage foundation"
     ```

   - Append two lines to every issue body before creating: a link back to the plan
     (`Plan: doc/plans/<slug>.md`) and the phase name (`Phase: <phase.title>`).

6. **Add each issue to the project board.** The repo's Projects v2 board is
   **"Meetings App — Delivery"**, `https://github.com/users/DandyCV/projects/2`,
   id `PVT_kwHOAvyPJ84Bh8Mv`. For every issue created (skip ones that were already
   present — assume they are already on the board):

   ```bash
   ISSUE_ID=$(gh issue view "<issue-url>" --json id --jq .id)
   gh api graphql -f query='mutation($p:ID!,$c:ID!){addProjectV2ItemById(input:{projectId:$p,contentId:$c}){item{id}}}' \
     -f p='PVT_kwHOAvyPJ84Bh8Mv' -f c="$ISSUE_ID"
   ```

7. **Report.** Print a table of every milestone and issue touched, `created` vs
   `reused/skipped`, with URLs (`gh issue create` prints the URL; capture it), and
   confirm each new issue was added to the project board.

## Notes

- **Idempotent by title.** Re-running after adding tasks to the plan creates only the
  new issues/milestones. It never edits or closes existing ones.
- Issue titles come verbatim from the `## Task ...` heading with backticks stripped.
  Issue bodies are the task's entire markdown section (Files / Interfaces / Steps).
- Do not add labels unless the user asks — this repo's spec tracker is separate
  (`docs/agents/issue-tracker.md`); these issues are task tracking only.
- The parser treats a non-phase `#` / non-task `##` heading outside code fences as the
  end of the plan's phase content, so a trailing "Self-Review" section is not scanned.

## Common mistakes

- Passing multi-KB task bodies as `-f`/`--body` inline — the shell mangles them. Always
  write the body to a temp file and use `--body-file` / `--input`.
- Creating milestones after issues — `gh issue create --milestone` resolves by title, so
  the milestone must exist first.
- Forgetting to check for existing objects — creating duplicates on a re-run.
