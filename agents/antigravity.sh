# Google Antigravity CLI — headless via `agy -p`.
# agy ignores the shell's cwd, so the working directory is passed with --add-dir
# and repeated in the brief.
ADAPTER_ID="antigravity"
ADAPTER_LABEL="Antigravity CLI (Google, agy)"
ADAPTER_BIN="agy"
ADAPTER_TAGS="UI and design, landing pages, CSS, quick prototypes, fast answers"
ADAPTER_INSTALL='install Antigravity from antigravity.google, then run agy once to sign in'

adapter_probe() {
  local bin; bin="$(command -v agy 2>/dev/null)"
  [ -n "$bin" ] || { echo "missing|agy is not installed"; return; }
  local v; v="$(agy --version 2>/dev/null | head -1)"
  if [ -s "$HOME/.gemini/config/config.json" ]; then
    echo "ok|agy $v"
  else
    echo "noauth|agy $v — run agy once and sign in"
  fi
}

_agy() { # _agy <extra-flag...> -- <dir> <brief> <model>
  local mode="$1" dir="$2" brief="$3" model="$4"
  local args=(-p "$(cat "$brief")" --add-dir "$dir" --dangerously-skip-permissions --print-timeout 20m)
  [ "$mode" = "plan" ] && args+=(--mode plan)
  [ -n "$model" ] && args+=(--model "$model")
  # agy is invoked by absolute path: the user's shell aliases it.
  "$(command -v agy)" "${args[@]}"
}

adapter_ask() { _agy plan        "$1" "$2" "${3:-}"; }
adapter_run() { _agy accept-edits "$1" "$2" "${3:-}"; }
