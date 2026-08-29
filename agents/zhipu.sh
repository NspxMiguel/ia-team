# Zhipu AI — OpenAI-compatible API teammate.
ADAPTER_ID="zhipu"
ADAPTER_LABEL="Zhipu AI"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="coding, reasoning, debugging, and multilingual repository work"
ADAPTER_INSTALL="key at https://open.bigmodel.cn/usercenter/apikeys, then: pbpaste | claude-autonomous secret import ZHIPU_API_KEY"
ADAPTER_KEY_ENV="ZHIPU_API_KEY"

CLOUD_BASE_URL="https://open.bigmodel.cn/api/paas/v4"
CLOUD_KEY_ENV="ZHIPU_API_KEY"
CLOUD_MODEL="glm-4.6"
CLOUD_ASK_MODEL="glm-4.6"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "ZHIPU_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
