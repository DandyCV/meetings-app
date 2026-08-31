#!/usr/bin/env python3
"""Parse an implementation plan (docs/plans/<slug>.md) into phases and tasks.

Phases are `# Phase ...` headings; tasks are `## Task ...` headings nested under
them. Headings inside fenced code blocks (``` or ~~~) are ignored. Emits JSON on
stdout:

  {
    "plan_path": "docs/plans/foo.md",
    "phases": [
      {
        "title": "Phase A - Storage foundation",
        "body": "<markdown between the phase heading and its first task>",
        "tasks": [
          {"title": "Task 1: Enable Active Storage", "body": "<full task section>"}
        ]
      }
    ]
  }

Usage: parse_plan.py docs/plans/<slug>.md
"""
import json
import re
import sys


def strip_title(text: str) -> str:
    # Drop markdown code-span backticks so GitHub titles read cleanly.
    return text.replace("`", "").strip()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: parse_plan.py <plan.md>", file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    phase_re = re.compile(r"^# Phase (.+)$")
    task_re = re.compile(r"^## Task (.+)$")
    # A non-phase `# ` or non-task `## ` heading ends the current phase's content.
    boundary_re = re.compile(r"^# (?!Phase )|^## (?!Task )")
    fence_re = re.compile(r"^\s*(```|~~~)")

    phases = []
    cur_phase = None
    cur_task = None
    buf = []
    in_fence = False

    def close_task():
        nonlocal cur_task, buf
        if cur_task is not None:
            cur_task["body"] = "\n".join(buf).strip()
            cur_phase["tasks"].append(cur_task)
            cur_task = None
        buf = []

    def close_phase_intro():
        nonlocal buf
        if cur_phase is not None and not cur_phase["tasks"]:
            cur_phase["body"] = "\n".join(buf).strip()
        buf = []

    for line in lines:
        if fence_re.match(line):
            in_fence = not in_fence
            buf.append(line)
            continue

        if in_fence:
            buf.append(line)
            continue

        phase_m = phase_re.match(line)
        if phase_m:
            if cur_task is not None:
                close_task()
            else:
                close_phase_intro()
            cur_phase = {"title": "Phase " + strip_title(phase_m.group(1)),
                         "body": "", "tasks": []}
            phases.append(cur_phase)
            buf = []
            continue

        if cur_phase is not None:
            task_m = task_re.match(line)
            if task_m:
                if cur_task is not None:
                    close_task()
                else:
                    close_phase_intro()
                cur_task = {"title": "Task " + strip_title(task_m.group(1)), "body": ""}
                buf = [line]
                continue

            if boundary_re.match(line):
                if cur_task is not None:
                    close_task()
                else:
                    close_phase_intro()
                cur_phase = None
                buf = []
                continue

        buf.append(line)

    if cur_task is not None:
        close_task()
    else:
        close_phase_intro()

    json.dump({"plan_path": path, "phases": phases}, sys.stdout, indent=2, ensure_ascii=False)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
