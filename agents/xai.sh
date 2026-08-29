# xAI — OpenAI-compatible API teammate.
ADAPTER_ID="xai"
ADAPTER_LABEL="xAI"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="fast reasoning, code generation, debugging, and architecture"
ADAPTER_INSTALL="key at https://console.x.ai (API Keys), then: pbpaste | claude-autonomous secret import XAI_API_KEY"
ADAPTER_KEY_ENV="XAI_API_KEY"

CLOUD_BASE_URL="https://api.x.ai/v1"
CLOUD_KEY_ENV="XAI_API_KEY"
CLOUD_MODEL="grok-4-fast-reasoning"
CLOUD_ASK_MODEL="grok-4-fast-reasoning"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "XAI_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
