# DeepInfra — OpenAI-compatible API teammate.
ADAPTER_ID="deepinfra"
ADAPTER_LABEL="DeepInfra"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="large coding models, bulk edits, and cost-effective inference"
ADAPTER_INSTALL="key at https://deepinfra.com/dash/api_keys, then: pbpaste | claude-autonomous secret import DEEPINFRA_API_KEY"
ADAPTER_KEY_ENV="DEEPINFRA_API_KEY"

CLOUD_BASE_URL="https://api.deepinfra.com/v1/openai"
CLOUD_KEY_ENV="DEEPINFRA_API_KEY"
CLOUD_MODEL="Qwen/Qwen3-Coder-480B-A35B-Instruct"
CLOUD_ASK_MODEL="Qwen/Qwen3-Coder-480B-A35B-Instruct"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "DEEPINFRA_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
