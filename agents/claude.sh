# Claude Code itself, as a teammate with a clean context. Useful for a genuine
# second read of your own work — a fresh session has none of your assumptions.
# Default model is Haiku: this is a helper, not the lead.
ADAPTER_ID="claude"
ADAPTER_LABEL="Claude Code (fresh session)"
ADAPTER_BIN="claude"
ADAPTER_TAGS="second read of a diff, code review, sweeping many files cheaply"
ADAPTER_INSTALL="already installed if you are reading this; otherwise: npm i -g @anthropic-ai/claude-code"

adapter_probe() {
  command -v claude >/dev/null 2>&1 || { echo "missing|claude is not installed"; return; }
  echo "ok|$(claude --version 2>/dev/null | head -1)"
}

_claude() { # _claude <permission-mode> <dir> <brief> <model>
  local perm="$1" dir="$2" brief="$3" model="${4:-haiku}"
  ( cd "$dir" && claude -p "$(cat "$brief")" \
      --permission-mode "$perm" --model "$model" --add-dir "$dir" )
}

adapter_ask() { _claude plan         "$1" "$2" "${3:-}"; }
adapter_run() { _claude acceptEdits  "$1" "$2" "${3:-}"; }
