# opencode — headless via `opencode run`. Model-agnostic: whatever provider the
# user authenticated with (`opencode providers`).
ADAPTER_ID="opencode"
ADAPTER_LABEL="opencode"
ADAPTER_BIN="opencode"
ADAPTER_TAGS="second opinion with another provider, scripted edits, cheap sweeps"
ADAPTER_INSTALL="curl -fsSL https://opencode.ai/install | bash, then: opencode providers"

adapter_probe() {
  command -v opencode >/dev/null 2>&1 || { echo "missing|opencode is not installed"; return; }
  local auth="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json"
  if [ -s "$auth" ] && python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])) else 1)' "$auth" 2>/dev/null; then
    echo "ok|$(opencode --version 2>/dev/null | tail -1)"
  else
    echo "noauth|no provider signed in — run: opencode providers"
  fi
}

# Without an explicit model opencode stops to ask for one, which hangs a
# headless run — so always resolve one first.
_oc_model() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json" m=""
  [ -s "$cfg" ] && m="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("model",""))' "$cfg" 2>/dev/null)"
  [ -n "$m" ] || m="$(opencode models 2>/dev/null | head -1)"
  printf '%s' "$m"
}

_opencode() { # _opencode <agent> <dir> <brief> <model>
  local agent="$1" dir="$2" brief="$3" model="$4"
  [ -n "$model" ] || model="$(_oc_model)"
  local args=(run --dir "$dir" --agent "$agent" --auto)
  [ -n "$model" ] && args+=(-m "$model")
  opencode "${args[@]}" "$(cat "$brief")"
}

adapter_ask() { _opencode plan  "$1" "$2" "${3:-}"; }
adapter_run() { _opencode build "$1" "$2" "${3:-}"; }
