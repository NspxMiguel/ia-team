#!/usr/bin/env bash
# ia-team installer — macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/NspxMiguel/ia-team/main/install.sh | bash
#
# Installs the `team` command, the agent adapters, and the `team` skill for
# Claude Code. Nothing is overwritten without a backup first.
set -euo pipefail

REPO="NspxMiguel/ia-team"
RAW="https://raw.githubusercontent.com/$REPO/main"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILL_DIR="$CLAUDE_DIR/skills/team"
TEAM_HOME="${IA_TEAM_HOME:-$HOME/.ia-team}"
BIN_DIR="$HOME/.local/bin"

ADAPTERS="codex antigravity opencode gemini cursor claude"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required (the worktrees depend on it)."
command -v python3 >/dev/null 2>&1 || die "python3 is required (it reads the run metadata)."

SRC=""
if [ -f "$(dirname "${BASH_SOURCE[0]:-}")/bin/team" ] 2>/dev/null; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

fetch() { # fetch <repo-relative-path> <destination>
  if [ -n "$SRC" ]; then
    cp "$SRC/$1" "$2"
  else
    curl -fsSL "$RAW/$1" -o "$2" || die "could not download $1"
  fi
}

backup() { [ -e "$1" ] && cp "$1" "$1.bak-$(date +%Y%m%d%H%M%S)" || true; }

say "ia-team"
say "======="
say ""

mkdir -p "$BIN_DIR" "$TEAM_HOME/agents" "$SKILL_DIR"

say "-> command in $BIN_DIR"
backup "$BIN_DIR/team"
fetch bin/team "$BIN_DIR/team"
chmod +x "$BIN_DIR/team"

say "-> adapters in $TEAM_HOME/agents"
for a in $ADAPTERS; do
  fetch "agents/$a.sh" "$TEAM_HOME/agents/$a.sh"
done

say "-> skill in $SKILL_DIR"
backup "$SKILL_DIR/SKILL.md"
fetch skill/SKILL.md "$SKILL_DIR/SKILL.md"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    say ""
    say "   note: $BIN_DIR is not on your PATH. Add this to your shell profile:"
    say "     export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

say ""
"$BIN_DIR/team" doctor || true
say ""
say "Done. Restart Claude Code so it picks up the skill, then try:"
say "  team panel \"what is the weakest part of this repo?\""
