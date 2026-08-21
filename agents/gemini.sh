# Gemini CLI — headless via `gemini --prompt`. Free tier with a Google account.
# The key comes from the environment, or from the keychain via claude-autonomous.
ADAPTER_ID="gemini"
ADAPTER_LABEL="Gemini CLI (Google, free tier)"
ADAPTER_KIND="cli"
ADAPTER_BIN="gemini"
ADAPTER_TAGS="huge context, long documents, research, docs, reading a whole codebase"
ADAPTER_INSTALL="npm i -g @google/gemini-cli, then run gemini once and sign in with Google (about 1000 requests/day). An AI Studio key also works (pbpaste | claude-autonomous secret import GEMINI_API_KEY) but the free tier there is only a handful of requests per day."
ADAPTER_KEY_ENV="GEMINI_API_KEY"

_gem_key_state() {
  [ -n "${GEMINI_API_KEY:-}" ] && { echo env; return; }
  if command -v claude-autonomous >/dev/null 2>&1 &&
     claude-autonomous secret list 2>/dev/null | grep -q '^  GEMINI_API_KEY$'; then
    echo keychain; return
  fi
  [ -s "$HOME/.gemini/oauth_creds.json" ] && { echo oauth; return; }
  echo missing
}

adapter_probe() {
  command -v gemini >/dev/null 2>&1 || { echo "missing|gemini is not installed"; return; }
  local v; v="$(gemini --version 2>/dev/null | tail -1)"
  case "$(_gem_key_state)" in
    missing) echo "noauth|gemini $v — no GEMINI_API_KEY; see: team hire gemini" ;;
    *)       echo "ok|gemini $v" ;;
  esac
}

_gemini() { # _gemini <approval> <dir> <brief> <model>
  local approval="$1" dir="$2" brief="$3" model="$4"
  local args=(--prompt "$(cat "$brief")" --approval-mode "$approval" --skip-trust)
  [ -n "$model" ] && args+=(-m "$model")
  if [ -n "${GEMINI_API_KEY:-}" ] || [ "$(_gem_key_state)" = oauth ]; then
    ( cd "$dir" && GEMINI_CLI_TRUST_WORKSPACE=true gemini "${args[@]}" )
  else
    ( cd "$dir" && GEMINI_CLI_TRUST_WORKSPACE=true \
        claude-autonomous run GEMINI_API_KEY -- gemini "${args[@]}" )
  fi
}

adapter_ask() { _gemini plan "$1" "$2" "${3:-}"; }
adapter_run() { _gemini yolo "$1" "$2" "${3:-}"; }
