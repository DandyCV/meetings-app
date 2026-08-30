#!/usr/bin/env bash
# PostToolUse(Write|Edit) hook: auto-format the file that was just changed.
# Frontend (apps/frontend) -> Prettier; backend (apps/backend) -> RuboCop -A.
# Mirrors `npm run format`. Never blocks: always exits 0.
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"

f="$(python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); sys.exit(0)
ti = d.get("tool_input") or {}
tr = d.get("tool_response") or {}
print(ti.get("file_path") or tr.get("filePath") or "")' 2>/dev/null)"

[ -n "$f" ] && [ -f "$f" ] || exit 0

case "$f" in
  "$root"/apps/frontend/*)
    case "$f" in
      *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.mdx|*.html|*.yml|*.yaml)
        (cd "$root/apps/frontend" && npx --no-install prettier --write --log-level warn "$f") >/dev/null 2>&1 || true
        ;;
    esac
    ;;
  "$root"/apps/backend/*)
    case "$f" in
      *.rb|*.rake|*.gemspec|*.ru)
        (cd "$root/apps/backend" && bin/rubocop -A --force-exclusion "$f") >/dev/null 2>&1 || true
        ;;
    esac
    ;;
esac

exit 0
