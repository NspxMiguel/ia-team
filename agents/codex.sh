# Codex CLI (OpenAI) — headless via `codex exec`.
ADAPTER_ID="codex"
ADAPTER_LABEL="Codex CLI (OpenAI)"
ADAPTER_BIN="codex"
ADAPTER_TAGS="big refactors, backend, tests, following a spec to the letter, code review"
ADAPTER_INSTALL="brew install codex   (or npm i -g @openai/codex), then: codex login"

adapter_probe() {
  command -v codex >/dev/null 2>&1 || { echo "missing|codex is not installed"; return; }
  local v; v="$(codex --version 2>/dev/null | head -1)"
  if [ -s "${CODEX_HOME:-$HOME/.codex}/auth.json" ]; then
    echo "ok|$v"
  else
    echo "noauth|$v — run: codex login"
  fi
}

_codex_exec() { # _codex_exec <sandbox> <verbose> <dir> <brief> <model>
  local sandbox="$1" verbose="$2" dir="$3" brief="$4" model="$5"
  local last log rc
  last="$(mktemp)"; log="$(mktemp)"
  local args=(exec --cd "$dir" --sandbox "$sandbox" --skip-git-repo-check --color never -o "$last")
  [ -n "$model" ] && args+=(-m "$model")
  codex "${args[@]}" - <"$brief" >"$log" 2>&1; rc=$?
  # A question wants the answer; a task wants the trail of what was done.
  if [ "$verbose" = "yes" ]; then
    cat "$log"
    [ -s "$last" ] && { printf '\n===== codex report =====\n'; cat "$last"; }
  elif [ -s "$last" ]; then
    cat "$last"
  else
    cat "$log"
  fi
  rm -f "$last" "$log"
  return $rc
}

adapter_ask() { _codex_exec read-only       no  "$1" "$2" "${3:-}"; }
adapter_run() { _codex_exec workspace-write yes "$1" "$2" "${3:-}"; }
