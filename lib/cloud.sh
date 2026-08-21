# Shared body for every OpenAI-compatible API teammate (Groq, NVIDIA, ...).
#
# An adapter that sources this file only has to declare who it is:
#   CLOUD_BASE_URL, CLOUD_KEY_ENV, CLOUD_MODEL, CLOUD_ASK_MODEL (optional)
# and then call cloud_ask / cloud_run.
#
# The API key never passes through this shell: when it is not already in the
# environment, the call is wrapped in `claude-autonomous run NAME -- ...`, which
# hands the value straight to the process.

_cloud_runner() {
  local d
  for d in "$TEAM_HOME/runner" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/runner"; do
    [ -f "$d/cloud_agent.py" ] && { printf '%s\n' "$d/cloud_agent.py"; return 0; }
  done
  return 1
}

# Is the key reachable — in the environment, or in the keychain?
cloud_key_state() { # cloud_key_state <ENV_NAME> -> env|keychain|missing
  local name="$1"
  [ -n "${!name:-}" ] && { echo env; return; }
  if command -v claude-autonomous >/dev/null 2>&1 &&
     claude-autonomous secret list 2>/dev/null | grep -q "^  $name$"; then
    echo keychain; return
  fi
  echo missing
}

cloud_probe() { # cloud_probe <ENV_NAME> <label>
  local name="$1" label="$2"
  _cloud_runner >/dev/null || { echo "missing|the runner is not installed"; return; }
  case "$(cloud_key_state "$name")" in
    env)      echo "ok|$label (key in \$$name)" ;;
    keychain) echo "ok|$label (key in the keychain)" ;;
    *)        echo "noauth|no $name — see: team hire $ADAPTER_ID" ;;
  esac
}

_cloud_exec() { # _cloud_exec <mode> <dir> <brief> <model>
  local mode="$1" dir="$2" brief="$3" model="${4:-}"
  local runner; runner="$(_cloud_runner)" || { echo "runner missing" >&2; return 2; }
  [ -n "$model" ] || model="$CLOUD_MODEL"
  [ "$mode" = "ask" ] && [ -n "${CLOUD_ASK_MODEL:-}" ] && [ -z "${4:-}" ] && model="$CLOUD_ASK_MODEL"

  local args=(/usr/bin/python3 "$runner"
    --base-url "$CLOUD_BASE_URL" --model "$model" --key-env "$CLOUD_KEY_ENV"
    --dir "$dir" --brief "$brief" --mode "$mode"
    --timeout "${TEAM_AGENT_TIMEOUT:-900}")

  if [ -n "${!CLOUD_KEY_ENV:-}" ]; then
    "${args[@]}"
  else
    claude-autonomous run "$CLOUD_KEY_ENV" -- "${args[@]}"
  fi
}

cloud_ask() { _cloud_exec ask "$1" "$2" "${3:-}"; }
cloud_run() { _cloud_exec run "$1" "$2" "${3:-}"; }
