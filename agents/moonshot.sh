# Moonshot AI — OpenAI-compatible API teammate.
ADAPTER_ID="moonshot"
ADAPTER_LABEL="Moonshot AI"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="long-context reasoning, debugging, and complex refactors"
ADAPTER_INSTALL="key at https://platform.moonshot.ai/console/api-keys, then: pbpaste | claude-autonomous secret import MOONSHOT_API_KEY"
ADAPTER_KEY_ENV="MOONSHOT_API_KEY"

CLOUD_BASE_URL="https://api.moonshot.ai/v1"
CLOUD_KEY_ENV="MOONSHOT_API_KEY"
CLOUD_MODEL="kimi-k2-thinking"
CLOUD_ASK_MODEL="kimi-k2-thinking"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "MOONSHOT_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
