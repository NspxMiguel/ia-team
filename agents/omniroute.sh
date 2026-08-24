# Omniroute (local gateway) — OpenAI-compatible API teammate.
ADAPTER_ID="omniroute"
ADAPTER_LABEL="Omniroute (local gateway)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="local gateway, multi-provider, optional key"
ADAPTER_INSTALL="run omniroute locally on port 20128, see: https://omniroute.ai"
ADAPTER_KEY_ENV="OMNIROUTE_API_KEY"

CLOUD_BASE_URL="http://localhost:20128/v1"
CLOUD_KEY_OPTIONAL=1
CLOUD_KEY_ENV="OMNIROUTE_API_KEY"
CLOUD_MODEL="auto/best-coding"
CLOUD_ASK_MODEL="auto/best-fast"

. "$TEAM_LIB/cloud.sh"

adapter_probe() {
  local endpoint="http://localhost:20128/v1/models"
  local timeout=2

  if ! command -v curl >/dev/null 2>&1; then
    echo "missing|curl is required"
    return
  fi

  if ! curl -s -m "$timeout" "$endpoint" >/dev/null 2>&1; then
    echo "down|Omniroute gateway is not running on localhost:20128 — start it and try again"
    return
  fi

  case "$(cloud_key_state "$CLOUD_KEY_ENV")" in
    env)      echo "ok|Omniroute gateway — key in \$$CLOUD_KEY_ENV" ;;
    keychain) echo "ok|Omniroute gateway — key in the keychain" ;;
    *)        echo "ok|Omniroute gateway (optional key)" ;;
  esac
}

_get_model() {
  local endpoint="http://localhost:20128/v1/models"
  local timeout=2
  local model
  model=$(curl -s -m "$timeout" "$endpoint" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo "${model:-gpt-4o}"
}

adapter_ask()   { cloud_ask "$1" "$2" "$(_get_model)"; }
adapter_run()   { cloud_run "$1" "$2" "$(_get_model)"; }
