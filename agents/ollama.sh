# Ollama (local) — OpenAI-compatible API teammate.
ADAPTER_ID="ollama"
ADAPTER_LABEL="Ollama (local)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="local, no key required, completely private"
ADAPTER_INSTALL="servidor no ar, mas sem modelo baixado. Baixe um antes de usar: ollama pull qwen2.5-coder (ou o de sua preferência) — o adaptador usa o primeiro instalado."
ADAPTER_KEY_ENV=""

CLOUD_BASE_URL="http://localhost:11434/v1"
CLOUD_KEY_OPTIONAL=1
CLOUD_KEY_ENV=""
CLOUD_MODEL="qwen2.5-coder"
CLOUD_ASK_MODEL=""

. "$TEAM_LIB/cloud.sh"

# A server that is up but has no model pulled is NOT ready.
#
# The probe used to answer "ok" as soon as the port answered, so `team doctor`
# listed ollama among those "ready to work" and every task then died with
# `HTTP 404: model 'qwen2.5-coder' not found`. The fallback model name in
# `_get_model` invented a model that had never been pulled, which turned a
# clear "nothing installed" into a confusing 404 at run time.
#
# ADAPTER_INSTALL already carried the right words for this state; the probe
# simply never returned a state that would show them.
adapter_probe() {
  local endpoint="http://localhost:11434/v1/models"
  local timeout=2
  local body

  if ! command -v curl >/dev/null 2>&1; then
    echo "missing|curl is required"
    return
  fi

  if ! body=$(curl -s -m "$timeout" "$endpoint" 2>/dev/null); then
    echo "down|Ollama is not running on localhost:11434"
    return
  fi

  local model
  model=$(printf '%s' "$body" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -z "$model" ]; then
    echo "missing|Ollama is running but has no model pulled — try: ollama pull qwen2.5-coder"
    return
  fi

  echo "ok|Ollama (local, $model)"
}

# Empty on purpose when nothing is pulled: callers must fail loudly rather than
# request a model that does not exist.
_get_model() {
  local endpoint="http://localhost:11434/v1/models"
  local timeout=2
  curl -s -m "$timeout" "$endpoint" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

_require_model() {
  local model
  model=$(_get_model)
  if [ -z "$model" ]; then
    echo "ollama has no model pulled — try: ollama pull qwen2.5-coder" >&2
    return 1
  fi
  printf '%s' "$model"
}

adapter_ask()   { local m; m=$(_require_model) || return 1; cloud_ask "$1" "$2" "$m"; }
adapter_run()   { local m; m=$(_require_model) || return 1; cloud_run "$1" "$2" "$m"; }
