# DeepSeek (paid, cheap) — OpenAI-compatible API teammate.
ADAPTER_ID="deepseek"
ADAPTER_LABEL="DeepSeek (paid, cheap)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="hard reasoning and long refactors at a low price"
ADAPTER_INSTALL="key at https://platform.deepseek.com/api_keys (paid), then: pbpaste | claude-autonomous secret import DEEPSEEK_API_KEY"
ADAPTER_KEY_ENV="DEEPSEEK_API_KEY"

CLOUD_BASE_URL="https://api.deepseek.com/v1"
CLOUD_KEY_ENV="DEEPSEEK_API_KEY"
CLOUD_MODEL="deepseek-chat"
CLOUD_ASK_MODEL="deepseek-chat"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "DEEPSEEK_API_KEY" "deepseek-chat"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
