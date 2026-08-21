#!/usr/bin/env bash
# Regenerates port/TEAM.md from the skill, so the instructions other agents get
# never drift from the ones Claude gets. Run it after editing skill/SKILL.md.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/skill/SKILL.md"
OUT="$ROOT/port/TEAM.md"

{
  cat <<'HEAD'
# Working as a team (ia-team)

You have a `team` command that puts the other AI CLIs on this machine to work —
Codex, Antigravity, Gemini, Groq, opencode and others. Use it the same way a
tech lead uses their team: split the job, brief each one, read what comes back.

Install: https://github.com/NspxMiguel/ia-team

HEAD
  # everything after the frontmatter and the original title
  awk 'BEGIN{fm=0}
       /^---$/ { fm++; next }
       fm < 2  { next }
       /^# Working as a team$/ && !seen { seen=1; next }
       { print }' "$SRC" | awk 'NF || started { started=1; print }'
} >"$OUT"

printf 'wrote %s (%s lines)\n' "$OUT" "$(wc -l <"$OUT" | tr -d ' ')"
