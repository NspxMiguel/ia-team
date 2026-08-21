# Cursor CLI — headless via `cursor-agent -p`.
ADAPTER_ID="cursor"
ADAPTER_LABEL="Cursor CLI (cursor-agent)"
ADAPTER_BIN="cursor-agent"
ADAPTER_TAGS="frontend, React/Next, quick fixes across many files"
ADAPTER_INSTALL="curl https://cursor.com/install -fsS | bash, then: cursor-agent login"

adapter_probe() {
  command -v cursor-agent >/dev/null 2>&1 || { echo "missing|cursor-agent is not installed"; return; }
  if cursor-agent status >/dev/null 2>&1; then
    echo "ok|$(cursor-agent --version 2>/dev/null | head -1)"
  else
    echo "noauth|not signed in — run: cursor-agent login"
  fi
}

_cursor() { # _cursor <force?> <dir> <brief> <model>
  local force="$1" dir="$2" brief="$3" model="$4"
  local args=(-p "$(cat "$brief")" --output-format text)
  [ "$force" = "write" ] && args+=(--force)
  [ -n "$model" ] && args+=(-m "$model")
  ( cd "$dir" && cursor-agent "${args[@]}" )
}

adapter_ask() { _cursor read  "$1" "$2" "${3:-}"; }
adapter_run() { _cursor write "$1" "$2" "${3:-}"; }
