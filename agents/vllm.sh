# vLLM (local) — OpenAI-compatible API teammate.
ADAPTER_ID="vllm"
ADAPTER_LABEL="vLLM (local)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="local, optional key, completely private"
ADAPTER_INSTALL="pip install vllm, then: vllm serve <model>"
ADAPTER_KEY_ENV="VLLM_API_KEY"

CLOUD_BASE_URL="http://localhost:8000/v1"
CLOUD_KEY_ENV="VLLM_API_KEY"
CLOUD_MODEL="qwen2.5-coder"
CLOUD_ASK_MODEL=""

. "$TEAM_LIB/cloud.sh"

adapter_probe() {
  local endpoint="http://localhost:8000/v1/models"
  local timeout=2

  if ! command -v curl >/dev/null 2>&1; then
    echo "missing|curl is required"
    return
  fi

  if ! curl -s -m "$timeout" "$endpoint" >/dev/null 2>&1; then
    echo "down|vLLM is not running on localhost:8000"
    return
  fi

  case "$(cloud_key_state "$CLOUD_KEY_ENV")" in
    env)      echo "ok|vLLM (local) — key in \$$CLOUD_KEY_ENV" ;;
    keychain) echo "ok|vLLM (local) — key in the keychain" ;;
    *)        echo "ok|vLLM (local, optional key)" ;;
  esac
}

_get_model() {
  local endpoint="http://localhost:8000/v1/models"
  local timeout=2
  local model
  model=$(curl -s -m "$timeout" "$endpoint" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo "${model:-qwen2.5-coder}"
}

adapter_ask()   { cloud_ask "$1" "$2" "$(_get_model)"; }
adapter_run()   { cloud_run "$1" "$2" "$(_get_model)"; }
