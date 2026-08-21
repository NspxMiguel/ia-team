# Gemini CLI — headless via `gemini -p`.
ADAPTER_ID="gemini"
ADAPTER_LABEL="Gemini CLI (Google)"
ADAPTER_BIN="gemini"
ADAPTER_TAGS="huge context, reading long documents, research, docs"
ADAPTER_INSTALL="npm i -g @google/gemini-cli, then run: gemini"

adapter_probe() {
  command -v gemini >/dev/null 2>&1 || { echo "missing|gemini is not installed"; return; }
  if [ -n "${GEMINI_API_KEY:-}" ] || [ -s "$HOME/.gemini/oauth_creds.json" ] || [ -s "$HOME/.gemini/config/config.json" ]; then
    echo "ok|$(gemini --version 2>/dev/null | head -1)"
  else
    echo "noauth|not signed in — run: gemini"
  fi
}

_gemini() { # _gemini <approval> <dir> <brief> <model>
  local approval="$1" dir="$2" brief="$3" model="$4"
  local args=(--prompt "$(cat "$brief")" --approval-mode "$approval")
  [ -n "$model" ] && args+=(-m "$model")
  ( cd "$dir" && gemini "${args[@]}" )
}

adapter_ask() { _gemini plan "$1" "$2" "${3:-}"; }
adapter_run() { _gemini yolo "$1" "$2" "${3:-}"; }
