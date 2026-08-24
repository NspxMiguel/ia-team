# LM Studio (local) — OpenAI-compatible API teammate.
ADAPTER_ID="lmstudio"
ADAPTER_LABEL="LM Studio (local)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="local, no key required, completely private"
ADAPTER_INSTALL="brew install --cask lmstudio, then enable LM Studio Server"
ADAPTER_KEY_ENV=""

CLOUD_BASE_URL="http://localhost:1234/v1"
CLOUD_KEY_ENV=""
CLOUD_MODEL="qwen2.5-coder"
CLOUD_ASK_MODEL=""

. "$TEAM_LIB/cloud.sh"

adapter_probe() {
  local endpoint="http://localhost:1234/v1/models"
  local timeout=2

  if ! command -v curl >/dev/null 2>&1; then
    echo "missing|curl is required"
    return
  fi

  if curl -s -m "$timeout" "$endpoint" >/dev/null 2>&1; then
    echo "ok|LM Studio (local, no key required)"
  else
    echo "down|LM Studio is not running on localhost:1234"
  fi
}

_get_model() {
  local endpoint="http://localhost:1234/v1/models"
  local timeout=2
  local model
  model=$(curl -s -m "$timeout" "$endpoint" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo "${model:-qwen2.5-coder}"
}

adapter_ask()   { cloud_ask "$1" "$2" "$(_get_model)"; }
adapter_run()   { cloud_run "$1" "$2" "$(_get_model)"; }
